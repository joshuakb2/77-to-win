import './globals';
import { WorkerRequest, WorkerResponse } from './workerTypes';

worker = new Worker('./worker.js');

const listeners = new Set<(response: WorkerResponse) => void>();

worker.onmessage = e => {
    let response: WorkerResponse = e.data;

    listeners.forEach(f => f(response));
};

export function submitWorkerRequest(req: WorkerRequest): void {
    if (!worker) {
        throw new Error('The worker does not exist!');
    }

    worker.postMessage(req);
}

export function onWorkerResponse(f: (response: WorkerResponse) => void): void {
    listeners.add(f);
}
