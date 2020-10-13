import typescript from '@rollup/plugin-typescript';
import nodeResolve from '@rollup/plugin-node-resolve';

export default {
    input: 'ts/worker.ts',
    output: {
        file: 'worker.js',
        format: 'iife',
        sourcemap: true,
        // globals: {
        //     'd3': 'd3',
        //     'topojson-client': 'topojson'
        // },
    },
    // external: [ 'd3', 'topojson-client' ],
    plugins: [ typescript(), nodeResolve() ]
};
