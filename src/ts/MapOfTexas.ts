import './globals';
import { getDistrictCount, range } from './sharedFunctions';
import { onWorkerResponse, submitWorkerRequest } from './workerInterface';
import { MapType } from './workerTypes';

const SVG_NS = 'http://www.w3.org/2000/svg';

export const democrat = Symbol('democrat');
export const republican = Symbol('republican');

export type Party = typeof democrat | typeof republican;
export interface District {
    party: Party;
    num: number;
}

type PathStatus = PathPending | PathPresent;

interface PathPending {
    type: 'pending';
}

interface PathPresent {
    type: 'present';
    path: SVGPathElement;
};

const districtPaths = new Map<MapType, Map<number, PathStatus>>();
const dataUpdateListeners = new Set<() => void>();
const workerHaltedListeners = new Set<() => void>();

onWorkerResponse(response => {
    switch (response.type) {
        case 'error':
            console.error('Worker error: ' + response.message);
            break;

        case 'pathCalculated': {
            let svgPath = getSvgPath(response.pathData);

            let districtsInThisMap = districtPaths.get(response.mapType);

            if (!districtsInThisMap) {
                districtsInThisMap = new Map();
                districtPaths.set(response.mapType, districtsInThisMap);
            }

            let pathStatus = districtsInThisMap.get(response.districtNum);

            if (pathStatus) {
                switch (pathStatus.type) {
                    case 'pending':
                        break;

                    case 'present':
                        return;
                }
            }

            districtsInThisMap.set(response.districtNum, {
                type: 'present',
                path: svgPath
            });

            dataUpdateListeners.forEach(f => f());
        }   break;

        case 'halted':
            workerHaltedListeners.forEach(f => f());
            break;
    }
});

type RenderState = 'none' | 'loading' | 'rendered';

class MapOfTexas extends HTMLElement {
    districtInfos: District[] | undefined;
    connected: boolean;
    onDistrictsUpdated: () => void;
    onWorkerHalted: () => void;
    renderState: RenderState;
    waitingForWorkerHalt: boolean;

    constructor() {
        super();
        this.attachShadow({ mode: 'open' });
        this.connected = false;
        this.waitingForWorkerHalt = false;
        this.renderState = 'none';
        this.onmousedown = e => {
            e.preventDefault();
            e.stopPropagation();
        };
    }

    connectedCallback() {
        this.connected = true;

        let districts = this.getAttribute('districts');

        if (!districts) {
            throw new Error('Invalid districts!');
        }

        this.onDistrictsUpdated = () => {
            this.update();
        };

        dataUpdateListeners.add(this.onDistrictsUpdated);

        this.onWorkerHalted = () => {
            this.waitingForWorkerHalt = false;
            this.update();
        };

        workerHaltedListeners.add(this.onWorkerHalted);

        this.districtInfos = parseDistricts(districts);
        this.update();
    }

    disconnectedCallback() {
        this.connected = false;
        this.renderState = 'none';
        this.shadowRoot!.innerHTML = '';
        dataUpdateListeners.delete(this.onDistrictsUpdated);
        workerHaltedListeners.delete(this.onWorkerHalted);
    }

    static get observedAttributes() {
        return [ 'width', 'height', 'districts', 'map-type', 'zoom' ];
    }

    attributeChangedCallback(name: string, oldValue: string, newValue: string) {
        if (!this.connected) {
            return;
        }

        if (oldValue === newValue) {
            return;
        }

        switch (name) {
            case 'zoom':
            case 'width':
            case 'height': {
                this.renderState = 'none';
                districtPaths.clear();
                this.waitingForWorkerHalt = true;
                submitWorkerRequest({ type: 'halt' });
                this.update();
                break;
            }

            case 'map-type':
                this.renderState = 'none';
                this.update();
                break;

            case 'districts':
                if (newValue.length === oldValue.length) {
                    this.diffDistricts(newValue);
                }
                else {
                    this.districtInfos = parseDistricts(newValue);
                }
                break;
        }
    }

    diffDistricts(newDistricts: string) {
        for (let i = 0; i < newDistricts.length; i++) {
            let districtStatus = districtPaths.get(this.getAttribute('map-type') as MapType)?.get(i + 1);
            let path = districtStatus?.type === 'present' ? districtStatus.path : null;

            if (newDistricts[i] === 'D') {
                if (this.districtInfos![i].party === republican) {
                    this.districtInfos![i].party = democrat;
                    path?.setAttributeNS(null, 'fill', 'blue');
                }
            }
            else if (newDistricts[i] === 'R') {
                if (this.districtInfos![i].party === democrat) {
                    this.districtInfos![i].party = republican;
                    path?.setAttributeNS(null, 'fill', 'red');
                }
            }
            else {
                throw new Error('Invalid character in district string ' + newDistricts[i]);
            }
        }
    }

    update() {
        let mapType = this.getAttribute('map-type') as MapType | null;

        if (!mapType) {
            return;
        }

        if (this.waitingForWorkerHalt) {
            this.showLoading();
            return;
        };

        if (!allDistrictsArePresent(mapType)) {
            this.showLoading();
            this.requestDistrictPaths();
            return;
        }

        this.render();
    }

    showLoading() {
        let mapType: MapType = this.getAttribute('map-type') as MapType;

        if (this.renderState === 'loading') {
            this.shadowRoot!.querySelector('#loading-text')!.textContent = getLoadingText(mapType);
        };

        let fontSize = `${Math.min(window.innerWidth, 800) / 40}px`;

        this.shadowRoot!.innerHTML = `
            <div style="width: ${this.getAttribute('width')}px; height: ${this.getAttribute('height')}px; text-align: center;">
                <div id="loading-text" style="font-size: ${fontSize}">${getLoadingText(mapType)}</div>
            </div>
        `;
        this.renderState = 'loading';
    }

    requestDistrictPaths() {
        let mapType = this.getAttribute('map-type') as MapType | null;
        let width = this.getAttribute('width');
        let height = this.getAttribute('height');
        let zoom = this.getAttribute('zoom')?.split(',').map(x => +x);;

        if (!mapType || !width || !height || !zoom || zoom.length !== 3 || zoom.some(isNaN)) return;

        let [ x, y, scale ] = zoom;

        let districtsByNum = districtPaths.get(mapType);

        if (!districtsByNum) {
            districtsByNum = new Map();
            districtPaths.set(mapType, districtsByNum);
        }

        let districtCount = getDistrictCount(mapType);
        let firstNumNeeded = (
            range(districtCount)
                .map(n => n + 1)
                .find(n => districtsByNum?.get(n)?.type !== 'present')
                ?? 1
        );

        submitWorkerRequest({
            type: 'calculatePath',
            dims: [ +width, +height ],
            zoom: { x, y, scale },
            mapType,
            firstNumNeeded
        });

        for (let n = firstNumNeeded; n <= districtCount; n++) {
            districtsByNum.set(n, { type: 'pending' });
        }
    }

    render() {
        if (this.renderState === 'rendered') return;

        const shadow = this.shadowRoot;

        if (!shadow) {
            throw new Error('No shadow root!');
        }

        let mapType = this.getAttribute('map-type') as MapType | null;
        let width = this.getAttribute('width');
        let height = this.getAttribute('height');

        if (!mapType || !width || !height) {
            return;
        }

        if (getDistrictCount(mapType) !== this.districtInfos?.length) {
            return;
        }

        shadow.innerHTML = '';

        let svg = document.createElementNS(SVG_NS, 'svg');
        svg.setAttributeNS(null, 'width', width);
        svg.setAttributeNS(null, 'height', height);
        svg.style.border = 'solid black 1px';

        districtPaths.get(mapType)!.forEach((status, num) => {
            let { path } = (status as PathPresent);
            let districtInfo = this.districtInfos![num - 1];

            path.setAttributeNS(null, 'fill', districtInfo.party === democrat ? 'blue' : 'red');

            path.onclick = e => {
                e.preventDefault();
                e.stopPropagation();

                sendToPort('setDistrictParty', {
                    districtNum: districtInfo.num,
                    newParty: districtInfo.party === republican ? 'democrat' : 'republican'
                });
            };

            svg.appendChild(path);
        });

        shadow.appendChild(svg);
        this.renderState = 'rendered';
    }
}

function getPresentDistrictsCount(mapType: MapType): number {
    let districtStatuses = districtPaths.get(mapType);
    let statusesArray = districtStatuses ? Array.from(districtStatuses.values()) : [];

    return statusesArray.filter(status => status.type === 'present').length;
}

function allDistrictsArePresent(mapType: MapType): boolean {
    return getPresentDistrictsCount(mapType) === getDistrictCount(mapType);
}

function getSvgPath(d: string): SVGPathElement {
    let path = document.createElementNS(SVG_NS, 'path');

    path.setAttributeNS(null, 'd', d);
    path.setAttributeNS(null, 'stroke', 'white');
    path.setAttributeNS(null, 'stroke-linejoin', '2');
    path.style.cursor = 'pointer';

    return path;
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

function getLoadingText(mapType: MapType): string {
    return `Loading... ${getPresentDistrictsCount(mapType)}/${getDistrictCount(mapType)} districts`;
}

window.customElements.define('map-of-texas', MapOfTexas);
