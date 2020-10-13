import * as d3 from 'd3-geo';
import { GeoProjection } from 'd3-geo';
import * as topojson from 'topojson-client';
import { Topology, Objects, GeometryObject } from 'topojson-specification';
import { getDistrictCount } from './sharedFunctions';

import { MapType, WorkerRequest, WorkerResponse } from './workerTypes';

// importScripts(
//     '../node_modules/d3-array/dist/d3-array.js',
//     '../node_modules/d3-geo/dist/d3-geo.js',
// );

const maps = new Map<MapType, Topology<TexasMapObjects>>();
const promisesForMaps = new Map<MapType, Promise<Topology<TexasMapObjects>>>();

var previousWidth = 0;
var previousHeight = 0;
var tunedProjection: GeoProjection | undefined = undefined;

let queuedRequestsComplete = Promise.resolve();

let currentRequestToken: Symbol;

onmessage = function(e) {
    let request: WorkerRequest = e.data;

    switch (request.type) {
        case 'calculatePath': {
            let { mapType, firstNumNeeded, width, height } = request;

            if (previousWidth !== width || previousHeight !== height) {
                tunedProjection = undefined;
                previousWidth = width;
                previousHeight = height;
            }

            currentRequestToken = Symbol();

            queuedRequestsComplete = queuedRequestsComplete.then(() =>
                calculatePath(
                    currentRequestToken,
                    mapType,
                    firstNumNeeded,
                    width,
                    height
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

async function calculatePath(requestToken: Symbol, mapType: MapType, districtNum: number, width: number, height: number) {
    let map = await getMap(mapType);

    let tunedProjection = getTunedProjection(map, width, height);
    let tunedPath = d3.geoPath().projection(tunedProjection);

    let districts = map.objects.districts;

    if (districts.type !== 'GeometryCollection') {
        console.error('Expected districts to be a GeometryCollection, but it\'s a ' + districts.type + '!');
        return;
    }

    let district = districts.geometries.find(district => getDistrictNum(mapType, district) == districtNum);

    if (!district) {
        throw new Error(`Map "${mapType}" has no district ${districtNum}.`);
    }

    let districtGeo = topojson.feature(map, district);

    if (districtGeo.type !== 'Feature') {
        throw new Error(`Map "${mapType}" district ${districtNum} is not a Feature.`);
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
        await calculatePath(requestToken, mapType, districtNum + 1, width, height);
    }
}

function getTunedProjection(map: Topology<TexasMapObjects>, width: number, height: number): GeoProjection {
    if (tunedProjection) return tunedProjection;

    let mapGeo = topojson.mesh(map);
    let center = d3.geoCentroid(mapGeo);
    let projection = d3.geoMercator().center(center).fitSize([width, height], mapGeo);

    return projection.scale(0.99 * projection.scale());
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
