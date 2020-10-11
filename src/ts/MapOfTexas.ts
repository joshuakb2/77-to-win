import * as d3 from 'd3';
import { Feature, Geometry, GeoJsonProperties } from 'geojson';
import * as topojson from 'topojson-client';

import './globals';

const SVG_NS = 'http://www.w3.org/2000/svg';

export const democrat = Symbol('democrat');
export const republican = Symbol('republican');

export type Party = typeof democrat | typeof republican;
export interface District {
    party: Party;
    path: SVGPathElement;
    num: number;
}

class MapOfTexas extends HTMLElement {
    districtInfos: District[] | undefined;
    connected: boolean;

    constructor() {
        super();
        this.attachShadow({ mode: 'open' });
        this.connected = false;
    }

    connectedCallback() {
        this.connected = true;

        let districts = this.getAttribute('districts');

        if (!districts) {
            throw new Error('Invalid districts!');
        }

        this.districtInfos = parseDistricts(districts);
        this.redraw();
    }

    disconnectedCallback() {
        this.connected = false;
    }

    attributeChangedCallback(name: string, oldValue: string, newValue: string) {
        if (!this.connected) {
            return;
        }

        if (oldValue === newValue) {
            return;
        }

        switch (name) {
            case 'width':
            case 'height':
                this.redraw();
                break;

            case 'districts':
                if (oldValue.length !== newValue.length) {
                    this.districtInfos = parseDistricts(newValue);
                    this.redraw();
                }
                else {
                    this.diffDistricts(newValue);
                }
                break;
        }
    }

    diffDistricts(newDistricts: string) {
        for (let i = 0; i < newDistricts.length; i++) {
            if (newDistricts[i] === 'D') {
                if (this.districtInfos![i].party === republican) {
                    this.districtInfos![i].party = democrat;
                    this.districtInfos![i].path.setAttributeNS(null, 'fill', 'blue');
                }
            }
            else if (newDistricts[i] === 'R') {
                if (this.districtInfos![i].party === democrat) {
                    this.districtInfos![i].party = republican;
                    this.districtInfos![i].path.setAttributeNS(null, 'fill', 'red');
                }
            }
            else {
                throw new Error('Invalid character in district string ' + newDistricts[i]);
            }
        }
    }

    redraw() {
        const shadow = this.shadowRoot;

        if (!shadow) {
            throw new Error('No shadow root!');
        }

        shadow.innerHTML = '';

        if (!map) {
            throw new Error('No map of Texas!');
        }

        let mapOfTexas = map;

        let texasGeo = topojson.mesh(mapOfTexas);

        let width = +(this.getAttribute('width') ?? 0);
        let height = +(this.getAttribute('height') ?? 0);

        if (width <= 0 || height <= 0) {
            throw new Error('Invalid dimensions!!!');
        }

        let svg = document.createElementNS(SVG_NS, 'svg');
        svg.setAttributeNS(null, 'width', `${width}`);
        svg.setAttributeNS(null, 'height', `${height}`);
        svg.style.border = 'solid black 1px';
        let center = d3.geoCentroid(texasGeo);
        let projection = d3.geoMercator().center(center).fitSize([width, height], texasGeo);
        let tunedProjection = projection.scale(0.99 * projection.scale());
        let tunedPath = d3.geoPath().projection(tunedProjection);

        let districts = mapOfTexas.objects.districts;

        if (districts.type !== 'GeometryCollection') {
            console.error('Expected districts to be a GeometryCollection, but it\'s a ' + districts.type + '!');
            return;
        }

        let districtGeos = districts.geometries.map(district =>
            topojson.feature(mapOfTexas, district)
        );

        if (!districtGeos.every(isTopoFeature)) {
            throw new Error('Map data contains a district that is not a Geometry.');
        }

        districtGeos.sort((a, b) => {
            return (+a.properties!.SLDUST) - (+b.properties!.SLDUST);
        });

        if (!this.districtInfos) {
            throw new Error('No district data!');
        }

        for (let [ districtInfo, districtGeo ] of zip(this.districtInfos, districtGeos)) {
            let districtPathData = tunedPath(districtGeo);

            if (!districtPathData) {
                console.error('Failed to generate path data for a district!');
                return;
            }

            districtInfo.path.setAttributeNS(null, 'd', districtPathData);
            districtInfo.path.setAttributeNS(null, 'fill', districtInfo.party === democrat ? 'blue' : 'red');
            districtInfo.path.setAttributeNS(null, 'stroke', 'white');
            districtInfo.path.setAttributeNS(null, 'stroke-linejoin', '2');

            districtInfo.path.style.cursor = 'pointer';

            districtInfo.path.onclick = () => {
                sendToPort('setDistrictParty', {
                    districtNum: districtInfo.num,
                    newParty: districtInfo.party === republican ? 'democrat' : 'republican'
                });
            };

            svg.appendChild(districtInfo.path);
        }

        shadow.appendChild(svg);
    }

    static get observedAttributes() {
        return [ 'width', 'height', 'districts' ];
    }
}

function parseDistricts(str: string): District[] {
    return Array.from(str).map((c, i) => {
        let path = document.createElementNS(SVG_NS, 'path');

        switch (c) {
            case 'R': return { party: republican, num: i + 1, path };
            case 'D': return { party: democrat, num: i + 1, path };
            default:
                throw new Error('Unexpected character in districts string: ' + c);
        }
    });
}

function isTopoFeature(x: any): x is Feature<Geometry, GeoJsonProperties> {
    return x.type == 'Feature';
}

function zip<A, B>(a: A[], b: B[]): [A, B][] {
    let length = Math.min(a.length, b.length);
    let r: [A, B][] = [];

    for (let i = 0; i < length; i++) {
        r[i] = [ a[i], b[i] ];
    }

    return r;
}

window.customElements.define('map-of-texas', MapOfTexas);
