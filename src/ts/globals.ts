export {};

declare global {
    interface Elm {
        Main: {
            init(options: ElmOptions): ElmApp;
        };
    }

    interface ElmOptions {
        node: Element;
        flags: any;
    }

    interface ElmApp {
        ports?: {
            [key: string]: ElmPort | undefined;
        };
    }

    interface ElmPort {
        send(value: any): void;
        subscribe(callback: Function): void;
    }

    var Elm: Elm;
    var elmApp: ElmApp | undefined;
    var init: (() => void) | undefined;

    function sendToPort(name: string, value: any): void;
    function subscribeToPort(name: string, callback: Function): void;
}

window.elmApp = undefined;
window.init = undefined;

// These functions are safer than trying to use a port directly
// because if a port isn't used in the Elm code, it doesn't end up
// in the compiled output, and trying to access it will result in
// a reference error.

window.sendToPort = function(name, value) {
    let portName = name + 'Port';

    window.elmApp?.ports?.[portName]?.send(value);
}

window.subscribeToPort = function(name, callback) {
    let portName = name + 'Port';

    window.elmApp?.ports?.[portName]?.subscribe(callback);
}
