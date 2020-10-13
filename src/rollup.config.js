import typescript from '@rollup/plugin-typescript';

export default {
    input: 'ts/index.ts',
    output: {
        file: 'index.js',
        format: 'iife',
        sourcemap: true,
        globals: {
            'd3': 'd3',
            'topojson-client': 'topojson'
        }
    },
    external: [ 'd3', 'topojson-client' ],
    plugins: [ typescript() ]
};
