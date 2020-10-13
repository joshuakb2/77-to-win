export type WorkerRequest = {
    type: 'calculatePath';
    width: number;
    height: number;
    mapType: MapType;
    firstNumNeeded: number;
} | {
    type: 'halt'
};

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
