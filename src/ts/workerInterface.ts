import { WorkerRequest, WorkerResponse } from './workerTypes';

const worker = new Worker('./worker.js');
const listeners = new Set<(response: WorkerResponse) => void>();

worker.onmessage = e => {
    let response: WorkerResponse = e.data;

    listeners.forEach(f => f(response));
};

export function submitWorkerRequest(req: WorkerRequest): void {
    worker.postMessage(req);
}

export function onWorkerResponse(f: (response: WorkerResponse) => void): void {
    listeners.add(f);
}
