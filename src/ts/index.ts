import './globals';
import './MapOfTexas';

init = function() {
    fetch('maps/texas_state_senate_2019.json')
        .then(async response => {
            let json;
            try {
                json = await response.json();
            }
            catch (err) {
                throw new Error('Failed to parse map JSON.');
            }

            map = json;
        })
        .catch(err => { console.error(err.stack); })
        .then(() => {
            if (map) {
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
            }
        });
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
