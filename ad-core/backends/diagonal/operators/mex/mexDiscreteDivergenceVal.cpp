//
// include necessary system headers
//
#include <cmath>
#include <mex.h>
#include <array>
#ifdef _OPENMP
    #include <omp.h>
#endif
#include <iostream>
#include <chrono>

/* MEX gateway */

void mexFunction( int nlhs, mxArray *plhs[], 
		  int nrhs, const mxArray *prhs[] )
     
{ 
    // In: 
    // acc (nc x 1) or empty
    // flux (nf x 1)
    // N (nf x 2)
    // nc (scalar)
    if (nrhs == 0) {
        if (nlhs > 0) {
            mexErrMsgTxt("Cannot give outputs with no inputs.");
        }
        // We are being called through compilation testing. Just do nothing. 
        // If the binary was actually called, we are good to go.
        return;
    } else if (nrhs != 4) {
	    mexErrMsgTxt("7 input arguments required."); 
    } else if (nlhs > 1) {
	    mexErrMsgTxt("Wrong number of output arguments."); 
    }
    const mxArray * acc = prhs[0];
    const mxArray * v = prhs[1];
    
    double * N = mxGetPr(prhs[2]);
    double * flux = mxGetPr(v);
    double nc = mxGetScalar(prhs[3]);

    int nf = mxGetM(prhs[1]);
    int n_acc = mxGetNumberOfElements(acc);
    
    bool has_accumulation = n_acc > 0;
    
    plhs[0] = mxCreateDoubleMatrix(nc, 1, mxREAL);
    double * result = mxGetPr(plhs[0]);
    #pragma omp parallel
    {
        if(has_accumulation){
            double * accumulation = mxGetPr(prhs[0]);
            #pragma omp for schedule(static)
            for(int i = 0; i < (int)nc; i++){
                result[i] = accumulation[i];
            }
        }
        #pragma omp for
        for(int f = 0; f < nf; f++){
            int c1 = N[f]-1;
            int c2 = N[f+nf]-1;
            #pragma omp atomic
            result[c1] += flux[f];
            #pragma omp atomic
            result[c2] -= flux[f];
        }
    }
}


