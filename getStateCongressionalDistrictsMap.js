#!/usr/bin/node

const fs = require('fs');

const stateCodes = new Map([
    [ 'ALABAMA', '01' ],
    [ 'ALASKA', '02' ],
    [ 'ARIZONA', '04' ],
    [ 'ARKANSAS', '05' ],
    [ 'CALIFORNIA', '06' ],
    [ 'COLORADO', '08' ],
    [ 'CONNECTICUT', '09' ],
    [ 'DELAWARE', '10' ],
    [ 'FLORIDA', '12' ],
    [ 'GEORGIA', '13' ],
    [ 'HAWAII', '15' ],
    [ 'IDAHO', '16' ],
    [ 'ILLINOIS', '17' ],
    [ 'INDIANA', '18' ],
    [ 'IOWA', '19' ],
    [ 'KANSAS', '20' ],
    [ 'KENTUCKY', '21' ],
    [ 'LOUISIANA', '22' ],
    [ 'MAINE', '23' ],
    [ 'MARYLAND', '24' ],
    [ 'MASSACHUSETTS', '25' ],
    [ 'MICHIGAN', '26' ],
    [ 'MINNESOTA', '27' ],
    [ 'MISSISSIPPI', '28' ],
    [ 'MISSOURI', '29' ],
    [ 'MONTANA', '30' ],
    [ 'NEBRASKA', '31' ],
    [ 'NEVADA', '32' ],
    [ 'NEW HAMPSHIRE', '33' ],
    [ 'NEW JERSEY', '34' ],
    [ 'NEW MEXICO', '35' ],
    [ 'NEW YORK', '36' ],
    [ 'NORTH CAROLINA', '37' ],
    [ 'NORTH DAKOTA', '38' ],
    [ 'OHIO', '39' ],
    [ 'OKLAHOMA', '40' ],
    [ 'OREGON', '41' ],
    [ 'PENNSYLVANIA', '42' ],
    [ 'RHODE ISLAND', '44' ],
    [ 'SOUTH CAROLINA', '45' ],
    [ 'SOUTH DAKOTA', '46' ],
    [ 'TENNESSEE', '47' ],
    [ 'TEXAS', '48' ],
    [ 'UTAH', '49' ],
    [ 'VERMONT', '50' ],
    [ 'VIRGINIA', '51' ],
    [ 'WASHINGTON', '53' ],
    [ 'WEST VIRGINIA', '54' ],
    [ 'WISCONSIN', '55' ],
    [ 'WYOMING', '56' ],
    [ 'AMERICAN SAMOA', '60' ],
    [ 'GUAM', '66' ],
    [ 'NORTHERN MARIANA ISLANDS', '69' ],
    [ 'PUERTO RICO', '72' ],
    [ 'VIRGIN ISLANDS', '78' ]
]);

function main() {
    let args = process.argv.slice(2);
    let getOutputFile = code => `tl_2019_${code}_cd116.json`;

    if (args[0] == '--out') {
        let outFile = args[1];

        if (!outFile) {
            printHelp(console.error);
            process.exit(1);
        }

        getOutputFile = () => outFile;
        args = args.slice(2);
    }

    let state = args.join(' ');

    if (state == '--help') {
        printHelp(console.log);
        process.exit(0);
    }

    if (state.match(/^[0-9]{2}$/)) {
        filterByStateCode(state, getOutputFile(state));
    }
    else if (stateCodes.has(state.toUpperCase())) {
        let code = stateCodes.get(state.toUpperCase());
        filterByStateCode(code, getOutputFile(code))
    }
    else {
        printHelp(console.error);
        process.exit(1);
    }
}

function printHelp(log) {
    log('Usage: ./getStateCongressionalDistrictsMap.js [--out <path.json>] <state name or 2-digit FIPS code>');
    log();
    log('Extracts just the part of the national congressional district map that pertains to a particular state');
    log('and saves it in a new TopoJSON file.');
}

function filterByStateCode(stateCode, outputFile) {
    let map = JSON.parse(fs.readFileSync('tl_2019_us_cd116.json').toString());
    let districtsInState = map.objects.tl_2019_us_cd116.geometries.filter(x => x.properties.STATEFP == stateCode);

    map.objects.tl_2019_us_cd116.geometries = districtsInState;

    console.log('Districts in state: ' + districtsInState.length);

    // The indices of the arcs that make up our districts
    let districtArcIndices = new Set(flatten(districtsInState.map(district => district.arcs)).map(getArcIndex));
    let districtArcIndicesArray = Array.from(districtArcIndices).sort((a, b) => a - b);

    // Only keep the arcs we need
    map.arcs = map.arcs.filter((_, i) => districtArcIndices.has(i));

    // Fix the indices in the geometry data since they changed in the previous step.
    map.objects.tl_2019_us_cd116.geometries.forEach(districts => {
        if (districts.type === 'MultiPolygon') {
            districts.arcs = districts.arcs.map(polygon =>
                polygon.map(boundary =>
                    boundary.map(getNewArcIndex)
                )
            );
        }
        else {
            districts.arcs = districts.arcs.map(boundary =>
                boundary.map(getNewArcIndex)
            );
        }
    });

    fs.writeFileSync(outputFile, JSON.stringify(map));

    function getNewArcIndex(arc) {
        if (arc < 0) {
            return ~districtArcIndicesArray.indexOf(~arc);
        }
        else {
            return districtArcIndicesArray.indexOf(arc);
        }
    }
}

function getArcIndex(arc) {
    return arc < 0 ? (~arc) : arc;
}

function flatten(arr) {
    if (arr instanceof Array) {
        return [].concat(...arr.map(flatten));
    }
    else {
        return arr;
    }
}

main();
