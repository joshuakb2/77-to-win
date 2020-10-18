export type WorkerRequest = {
    type: 'calculatePath';
    dims: [ number, number ];
    zoom: Zoom;
    mapType: MapType;
    firstNumNeeded: number;
} | {
    type: 'halt'
};

export interface Zoom {
    x: number;
    y: number;
    scale: number;
}

export type WorkerResponse = {
    type: 'error';
    message: string;
} | {
    type: 'pathCalculated';
    mapType: MapType;
    districtNum: number;
    pathData: string;
} | {
    type: 'halted'
};

export type MapType = 'senate' | 'house' | 'education' | 'congress';
