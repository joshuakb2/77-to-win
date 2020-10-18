import './globals';
import './MapOfTexas';

init = function() {
    elmApp = Elm.Main.init({
        node: document.querySelector('#app')!,
        flags: {
            width: window.innerWidth,
            height: window.innerHeight,
            parties: tryParse(localStorage.getItem('parties')),
            timezoneOffset: new Date().getTimezoneOffset()
        }
    });

    subscribeToPort('writeLocalStorage', writeLocalStorage);
    subscribeToPort('consoleError', console.error);

    window.onresize = () => {
        sendToPort('windowResized', [ window.innerWidth, window.innerHeight ]);
    };
};

function tryParse(s: any) {
    try {
        return JSON.parse(s);
    }
    catch (err) {
        return null;
    }
}

interface writeLocalStorageArgs {
    name: string;
    data: any;
    id: number;
}

function writeLocalStorage({ name, data, id }: writeLocalStorageArgs) {
    localStorage.setItem(name, JSON.stringify(data));
    sendToPort('writeLocalStorageCompleted', id);
}
