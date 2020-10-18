import * as d3 from 'd3-geo';
import { GeoProjection } from 'd3-geo';
import { Feature, Geometry } from 'geojson';
import * as topojson from 'topojson-client';
import { Topology, Objects, GeometryObject } from 'topojson-specification';
import { getDistrictCount } from './sharedFunctions';

import { MapType, WorkerRequest, WorkerResponse, Zoom } from './workerTypes';

const maps = new Map<MapType, Topology<TexasMapObjects>>();
const promisesForMaps = new Map<MapType, Promise<Topology<TexasMapObjects>>>();
const districtGeosByMapType = new Map<MapType, Map<number, Feature<Geometry, TexasMapProperties>>>();

var previousWidth = 0;
var previousHeight = 0;
var previousZoom = { x: 0, y: 0, scale: 1 };
var tunedProjection: GeoProjection | undefined = undefined;

let queuedRequestsComplete = Promise.resolve();

let currentRequestToken: Symbol;

onmessage = function(e) {
    let request: WorkerRequest = e.data;

    switch (request.type) {
        case 'calculatePath': {
            let { mapType, firstNumNeeded, dims: [ width, height ], zoom } = request;

            if (
                previousWidth !== width ||
                previousHeight !== height ||
                zoomsDiffer(zoom, previousZoom)
            ) {
                tunedProjection = undefined;
                previousWidth = width;
                previousHeight = height;
                previousZoom = zoom;
            }

            currentRequestToken = Symbol();

            queuedRequestsComplete = queuedRequestsComplete.then(() =>
                calculatePath(
                    currentRequestToken,
                    mapType,
                    firstNumNeeded,
                    width,
                    height,
                    zoom
                ).catch(err => {
                    console.error(err.stack);
                })
            );
            break;
        }

        case 'halt': {
            currentRequestToken = Symbol();

            queuedRequestsComplete.then(() => {
                postMessage({ type: 'halted' });
            });
        }
    }
};

interface WorkerError extends ErrorEvent {
    message: string;
    filename: string;
    lineno: number;
}

declare var onerror: (err: WorkerError) => void;
declare const postMessage: (response: WorkerResponse) => void;

onerror = function(err) {
    postMessage({
        type: 'error',
        message: `${err.filename}:${err.lineno}: ${err.message}`
    });
};

async function calculatePath(requestToken: Symbol, mapType: MapType, districtNum: number, width: number, height: number, zoom: Zoom) {
    let map = await getMap(mapType);
    let tunedProjection = getTunedProjection(map, width, height, zoom);
    let tunedPath = d3.geoPath().projection(tunedProjection);

    let districtGeos = districtGeosByMapType.get(mapType);

    if (!districtGeos) {
        districtGeos = new Map();
        districtGeosByMapType.set(mapType, districtGeos);
    }

    let districtGeo = districtGeos.get(districtNum);

    if (!districtGeo) {
        let districts = map.objects.districts;

        if (districts.type !== 'GeometryCollection') {
            console.error('Expected districts to be a GeometryCollection, but it\'s a ' + districts.type + '!');
            return;
        }

        let district = districts.geometries.find(district => getDistrictNum(mapType, district) == districtNum);

        if (!district) {
            throw new Error(`Map "${mapType}" has no district ${districtNum}.`);
        }

        if (district.type !== 'Polygon') {
            console.error(`Expected district ${districtNum} of map "${mapType}" to be a Polygon, but it's a ${districts.type}!`);
            return;
        }

        districtGeo = topojson.feature(map, district);

        if (districtGeo.type !== 'Feature') {
            throw new Error(`Map "${mapType}" district ${districtNum} is not a Feature.`);
        }

        districtGeos.set(districtNum, districtGeo);
    }

    let districtPathData = tunedPath(districtGeo);

    if (!districtPathData) {
        throw new Error(`Failed to generate path data for district ${districtNum} of map "${mapType}"!`);
    }

    postMessage({
        type: 'pathCalculated',
        pathData: districtPathData,
        mapType,
        districtNum
    });

    // Process incoming requests
    await yieldCpu();

    if (currentRequestToken !== requestToken) return;

    if (districtNum < getDistrictCount(mapType)) {
        await calculatePath(requestToken, mapType, districtNum + 1, width, height, zoom);
    }
}

function getTunedProjection(map: Topology<TexasMapObjects>, width: number, height: number, zoom: Zoom): GeoProjection {
    if (tunedProjection) return tunedProjection;

    let mapGeo = topojson.mesh(map);
    let center = d3.geoCentroid(mapGeo);
    let projection = d3.geoMercator().center(center).fitSize([width, height], mapGeo);

    projection.scale(0.99 * zoom.scale * projection.scale());

    let before = projection.translate();

    (([ x, y ]) => projection.translate([ zoom.x * x, zoom.y * y ]))(projection.translate());;

    let after = projection.translate();

    console.log('Desired/default: ', [ after[0] / before[0], after[1] / before[1] ]);

    tunedProjection = projection;

    return projection;
}

type TexasMapObjects = Objects<TexasMapProperties>;
type TexasMapProperties = {
    SLDUST: string;
    SLDLST: string;
    CD116FP: string;
    District: number;
};

function getDistrictNum(mapType: MapType, district: GeometryObject<TexasMapProperties>): number {
    let key: keyof TexasMapProperties;

    switch (mapType) {
        case 'senate': key = 'SLDUST';  break;
        case 'house': key = 'SLDLST';   break;
        case 'congress': key = 'CD116FP';   break;
        case 'education': key = 'District'; break;
    }

    return +((district.properties as TexasMapProperties)[key]);
}

async function getMap(mapType: MapType): Promise<Topology<TexasMapObjects>> {
    let map = maps.get(mapType);

    if (map) return map;

    let promiseForMap = promisesForMaps.get(mapType);

    if (promiseForMap) return promiseForMap;

    promiseForMap = (async () => {
        let response = await fetch(getMapPath(mapType));
        let map: Topology<TexasMapObjects> = await response.json();

        maps.set(mapType, map);
        promisesForMaps.delete(mapType);

        return map;
    })();

    promisesForMaps.set(mapType, promiseForMap);

    return promiseForMap;
}

function getMapPath(mapType: MapType): string {
    switch (mapType) {
        case 'congress': return 'maps/texas_congressional_2019.json';
        case 'senate': return 'maps/texas_state_senate_2019.json';
        case 'house': return 'maps/texas_state_house_2019.json';
        case 'education': return 'maps/texas_board_of_education_2019.json';
    }
}

function yieldCpu(): Promise<void> {
    return new Promise(resolve => {
        setTimeout(resolve, 0);
    });
}

function zoomsDiffer(a: Zoom, b: Zoom): boolean {
    return a.x !== b.x || a.y !== b.y || a.scale !== b.scale;
}
