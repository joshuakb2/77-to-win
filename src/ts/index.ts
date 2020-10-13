import './globals';
import './MapOfTexas';

init = function() {
    elmApp = Elm.Main.init({
        node: document.querySelector('#app')!,
        flags: {
            width: window.innerWidth,
            height: window.innerHeight,
            districts: tryParse(localStorage.getItem('districts')),
            timezoneOffset: new Date().getTimezoneOffset()
        }
    });

    subscribeToPort('writeLocalStorage', writeLocalStorage);
    subscribeToPort('consoleError', console.error);
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
