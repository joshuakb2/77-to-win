import { MapType } from './workerTypes';

export function range(n: number): number[] {
    let r = [];

    for (let i = 0; i < n; i++) {
        r.push(i);
    }

    return r;
}

export function getDistrictCount(mapType: MapType): number {
    switch (mapType) {
        case 'congress': return 36;
        case 'senate': return 31;
        case 'house': return 150;
        case 'education': return 15;
    }
}
