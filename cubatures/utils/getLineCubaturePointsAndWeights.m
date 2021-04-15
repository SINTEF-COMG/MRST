function [x, w, n, xR] = getLineCubaturePointsAndWeights(k)
    % Get line cubature points and weights for a cubature of precision k,
    % taken from the book "P. Solin, K. Segeth and I. Dolezel: Higher-Order
    % Finite Element Methods", Chapman & Hall/CRC Press, 2003.
    %
    % SYNOPSIS:
    %
    %   [x, w, n, xR] = getLineCubaturePointsAndWeights(k)
    %
    % PARAMETERS:
    %   k - cubature prescision
    %
    % RETURNS:
    %   x  - Cubature points
    %   w  - Cubature weights
    %   n  - Number of cubature points
    %   xR - Coordinates of reference line

%{
Copyright 2009-2021 SINTEF Digital, Mathematics & Cybernetics.

This file is part of The MATLAB Reservoir Simulation Toolbox (MRST).

MRST is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

MRST is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with MRST.  If not, see <http://www.gnu.org/licenses/>.
%}

    xR = [-1,1];
    
    if k <= 1
        
        xw = [0, 2];
        
    elseif k <= 3

        xw = [  -0.5773502691896257645091488  1.0000000000000000000000000
                 0.5773502691896257645091488  1.0000000000000000000000000];
            
    elseif k <= 5

        xw = [  -0.7745966692414833770358531  0.5555555555555555555555556
                 0.0000000000000000000000000  0.8888888888888888888888889
                 0.7745966692414833770358531  0.5555555555555555555555556];
                
    elseif k <= 7

        xw = [  -0.8611363115940525752239465  0.3478548451374538573730639
                -0.3399810435848562648026658  0.6521451548625461426269361
                 0.3399810435848562648026658  0.6521451548625461426269361
                 0.8611363115940525752239465  0.3478548451374538573730639];
    
    elseif k <= 9
    
        xw = [  -0.9061798459386639927976269  0.2369268850561890875142640
                -0.5384693101056830910363144  0.4786286704993664680412915
                 0.0000000000000000000000000  0.5688888888888888888888889
                 0.5384693101056830910363144  0.4786286704993664680412915
                 0.9061798459386639927976269  0.2369268850561890875142640];

    elseif k <= 11

        xw = [  -0.9324695142031520278123016  0.1713244923791703450402961
                -0.6612093864662645136613996  0.3607615730481386075698335
                -0.2386191860831969086305017  0.4679139345726910473898703
                 0.2386191860831969086305017  0.4679139345726910473898703
                 0.6612093864662645136613996  0.3607615730481386075698335
                 0.9324695142031520278123016  0.1713244923791703450402961];
    
    elseif k <= 13

        xw = [  -0.9491079123427585245261897  0.1294849661688696932706114
                -0.7415311855993944398638648  0.2797053914892766679014678
                -0.4058451513773971669066064  0.3818300505051189449503698
                 0.0000000000000000000000000  0.4179591836734693877551020
                 0.4058451513773971669066064  0.3818300505051189449503698
                 0.7415311855993944398638648  0.2797053914892766679014678
                 0.9491079123427585245261897  0.1294849661688696932706114];
    
    elseif k <= 15

        xw = [  -0.9602898564975362316835609  0.1012285362903762591525314
                -0.7966664774136267395915539  0.2223810344533744705443560
                -0.5255324099163289858177390  0.3137066458778872873379622
                -0.1834346424956498049394761  0.3626837833783619829651504
                 0.1834346424956498049394761  0.3626837833783619829651504
                 0.5255324099163289858177390  0.3137066458778872873379622
                 0.7966664774136267395915539  0.2223810344533744705443560
                 0.9602898564975362316835609  0.1012285362903762591525314];

    elseif k <= 17

        xw = [  -0.9681602395076260898355762  0.0812743883615744119718922
                -0.8360311073266357942994297  0.1806481606948574040584720
                -0.6133714327005903973087020  0.2606106964029354623187429
                -0.3242534234038089290385380  0.3123470770400028400686304
                 0.0000000000000000000000000  0.3302393550012597631645251
                 0.3242534234038089290385380  0.3123470770400028400686304
                 0.6133714327005903973087020  0.2606106964029354623187429
                 0.8360311073266357942994298  0.1806481606948574040584720
                 0.9681602395076260898355762  0.0812743883615744119718922];
    
    elseif k <= 19

        xw = [  -0.9739065285171717200779640  0.0666713443086881375935688
                -0.8650633666889845107320967  0.1494513491505805931457763
                -0.6794095682990244062343274  0.2190863625159820439955349
                -0.4333953941292471907992659  0.2692667193099963550912269
                -0.1488743389816312108848260  0.2955242247147528701738930
                 0.1488743389816312108848260  0.2955242247147528701738930
                 0.4333953941292471907992659  0.2692667193099963550912269
                 0.6794095682990244062343274  0.2190863625159820439955349
                 0.8650633666889845107320967  0.1494513491505805931457763
                 0.9739065285171717200779640  0.0666713443086881375935688];
            
    else
    
        error('Precision not supported');
        
    end
   
    x = xw(:,1);
    w = xw(:,2)/2;
    n = numel(w);

end
