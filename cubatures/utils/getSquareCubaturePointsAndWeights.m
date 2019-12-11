function [x, w, n, xR] = getSquareCubaturePointsAndWeights(k)
    % Get square cubature points and weights for a cubature of precision k,
    % taken from the book "P. Solin, K. Segeth and I. Dolezel: Higher-Order
    % Finite Element Methods", Chapman & Hall/CRC Press, 2003.
    %
    % SYNOPSIS:
    %
    %   [x, w, n, xR] = getSquareCubaturePointsAndWeights(k)
    %
    % PARAMETERS:
    %   k - cubature prescision
    %
    % RETURNS:
    %   x  - Cubature points
    %   w  - Cubature weights
    %   n  - Number of cubature points
    %   xR - Coordinates of reference square

%{
Copyright 2009-2019 SINTEF Digital, Mathematics & Cybernetics.

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

    xR = [-1, -1;
           1, -1;
           1,  1;
          -1,  1];

    if k <= 1

        xw = [0.000000000000000  0.000000000000000  4.000000000000000];

    elseif k <= 3

        xw = [ 0.577350269189626   0.577350269189626  1.000000000000000
               0.577350269189626  -0.577350269189626  1.000000000000000
              -0.577350269189626   0.577350269189626  1.000000000000000
              -0.577350269189626  -0.577350269189626  1.000000000000000];

    elseif k <= 5

        xw = [ 0.683130051063973   0.000000000000000  0.816326530612245
              -0.683130051063973   0.000000000000000  0.816326530612245
               0.000000000000000   0.683130051063973  0.816326530612245
               0.000000000000000  -0.683130051063973  0.816326530612245
               0.881917103688197   0.881917103688197  0.183673469387755
               0.881917103688197  -0.881917103688197  0.183673469387755
              -0.881917103688197   0.881917103688197  0.183673469387755
              -0.881917103688197  -0.881917103688197  0.183673469387755];

    elseif k <= 7

        xw = [ 0.925820099772551   0.000000000000000  0.241975308641975
              -0.925820099772551   0.000000000000000  0.241975308641975
               0.000000000000000   0.925820099772551  0.241975308641975
               0.000000000000000  -0.925820099772551  0.241975308641975
               0.805979782918599   0.805979782918599  0.237431774690630
               0.805979782918599  -0.805979782918599  0.237431774690630
              -0.805979782918599   0.805979782918599  0.237431774690630
              -0.805979782918599  -0.805979782918599  0.237431774690630
               0.380554433208316   0.380554433208316  0.520592916667394
               0.380554433208316  -0.380554433208316  0.520592916667394
              -0.380554433208316   0.380554433208316  0.520592916667394
              -0.380554433208316  -0.380554433208316  0.520592916667394];

    elseif k <= 9

        xw = [ 1.121225763866564   0.000000000000000  0.018475842507491
              -1.121225763866564   0.000000000000000  0.018475842507491
               0.000000000000000   1.121225763866564  0.018475842507491
               0.000000000000000  -1.121225763866564  0.018475842507491
               0.451773049920657   0.000000000000000  0.390052939160735
              -0.451773049920657   0.000000000000000  0.390052939160735
               0.000000000000000   0.451773049920657  0.390052939160735
               0.000000000000000  -0.451773049920657  0.390052939160735
               0.891849420851512   0.891849420851512  0.083095178026482
               0.891849420851512  -0.891849420851512  0.083095178026482
              -0.891849420851512   0.891849420851512  0.083095178026482
              -0.891849420851512  -0.891849420851512  0.083095178026482
               0.824396370749276   0.411623426336542  0.254188020152646
               0.824396370749276  -0.411623426336542  0.254188020152646
              -0.824396370749276   0.411623426336542  0.254188020152646
              -0.824396370749276  -0.411623426336542  0.254188020152646
               0.411623426336542   0.824396370749276  0.254188020152646
               0.411623426336542  -0.824396370749276  0.254188020152646
              -0.411623426336542   0.824396370749276  0.254188020152646
              -0.411623426336542  -0.824396370749276  0.254188020152646];

    elseif k <= 11

         xw = [ 0.000000000000000  0.000000000000000  0.365379525585903
                1.044402915409813  0.000000000000000  0.027756165564204
               -1.044402915409813  0.000000000000000  0.027756165564204
                0.000000000000000  1.044402915409813  0.027756165564204
                0.000000000000000  -1.044402915409813  0.027756165564204
                0.769799068396649  0.000000000000000  0.244272057751754
               -0.769799068396649  0.000000000000000  0.244272057751754
                0.000000000000000  0.769799068396649  0.244272057751754
                0.000000000000000  -0.769799068396649  0.244272057751754
                0.935787012440540  0.935787012440540  0.034265103851229
                0.935787012440540  -0.935787012440540  0.034265103851229
               -0.935787012440540  0.935787012440540  0.034265103851229
               -0.935787012440540  -0.935787012440540  0.034265103851229
                0.413491953449114  0.413491953449114  0.308993036133713
                0.413491953449114  -0.413491953449114  0.308993036133713
               -0.413491953449114  0.413491953449114  0.308993036133713
               -0.413491953449114  -0.413491953449114  0.308993036133713
                0.883025508525690  0.575653595840465  0.146684377651312
                0.883025508525690  -0.575653595840465  0.146684377651312
               -0.883025508525690  0.575653595840465  0.146684377651312
               -0.883025508525690  -0.575653595840465  0.146684377651312
                0.575653595840465  0.883025508525690  0.146684377651312
                0.575653595840465  -0.883025508525690  0.146684377651312
               -0.575653595840465  0.883025508525690  0.146684377651312
               -0.575653595840465  -0.883025508525690  0.146684377651312];

    elseif k <= 13

           xw = [1.086056158573971  0.000000000000000  0.005656169693764
                -1.086056158573971  0.000000000000000  0.005656169693764
                0.000000000000000  1.086056158573971  0.005656169693764
                0.000000000000000  -1.086056158573971  0.005656169693764
                0.658208197042585  0.000000000000000  0.192443967470396
                -0.658208197042585  0.000000000000000  0.192443967470396
                0.000000000000000  0.658208197042585  0.192443967470396
                0.000000000000000  -0.658208197042585  0.192443967470396
                1.001300602991729  1.001300602991729  0.005166832979773
                1.001300602991729  -1.001300602991729  0.005166832979773
                -1.001300602991729  1.001300602991729  0.005166832979773
                -1.001300602991729  -1.001300602991729  0.005166832979773
                0.584636168775946  0.584636168775946  0.200302559622138
                0.584636168775946  -0.584636168775946  0.200302559622138
                -0.584636168775946  0.584636168775946  0.200302559622138
                -0.584636168775946  -0.584636168775946  0.200302559622138
                0.246795612720261  0.246795612720261  0.228125175912536
                0.246795612720261  -0.246795612720261  0.228125175912536
                -0.246795612720261  0.246795612720261  0.228125175912536
                -0.246795612720261  -0.246795612720261  0.228125175912536
                0.900258815287201  0.304720678579870  0.117496926974491
                0.900258815287201  -0.304720678579870  0.117496926974491
                -0.900258815287201  0.304720678579870  0.117496926974491
                -0.900258815287201  -0.304720678579870  0.117496926974491
                0.304720678579870  0.900258815287201  0.117496926974491
                0.304720678579870  -0.900258815287201  0.117496926974491
                -0.304720678579870  0.900258815287201  0.117496926974491
                -0.304720678579870  -0.900258815287201  0.117496926974491
                0.929866705560780  0.745052720131169  0.066655770186205
                0.929866705560780  -0.745052720131169  0.066655770186205
                -0.929866705560780  0.745052720131169  0.066655770186205
                -0.929866705560780  -0.745052720131169  0.066655770186205
                0.745052720131169  0.929866705560780  0.066655770186205
                0.745052720131169  -0.929866705560780  0.066655770186205
                -0.745052720131169  0.929866705560780  0.066655770186205
                -0.745052720131169  -0.929866705560780  0.066655770186205];

    elseif k <= 15

          xw = [0.000000000000000  0.000000000000000  -0.001768979827207
                1.027314357719367  0.000000000000000  0.012816726617512
                -1.027314357719367  0.000000000000000  0.012816726617512
                0.000000000000000  1.027314357719367  0.012816726617512
                0.000000000000000  -1.027314357719367  0.012816726617512
                0.856766776147643  0.000000000000000  0.119897873101347
                -0.856766776147643  0.000000000000000  0.119897873101347
                0.000000000000000  0.856766776147643  0.119897873101347
                0.000000000000000  -0.856766776147643  0.119897873101347
                0.327332998189723  0.000000000000000  0.210885452208801
                -0.327332998189723  0.000000000000000  0.210885452208801
                0.000000000000000  0.327332998189723  0.210885452208801
                0.000000000000000  -0.327332998189723  0.210885452208801
                0.967223740028505  0.967223740028505  0.006392720128215
                0.967223740028505  -0.967223740028505  0.006392720128215
                -0.967223740028505  0.967223740028505  0.006392720128215
                -0.967223740028505  -0.967223740028505  0.006392720128215
                0.732168901749711  0.732168901749711  0.104415680788580
                0.732168901749711  -0.732168901749711  0.104415680788580
                -0.732168901749711  0.732168901749711  0.104415680788580
                -0.732168901749711  -0.732168901749711  0.104415680788580
                0.621974427996805  0.321696694921009  0.168053047203816
                0.621974427996805  -0.321696694921009  0.168053047203816
                -0.621974427996805  0.321696694921009  0.168053047203816
                -0.621974427996805  -0.321696694921009  0.168053047203816
                0.321696694921009  0.621974427996805  0.168053047203816
                0.321696694921009  -0.621974427996805  0.168053047203816
                -0.321696694921009  0.621974427996805  0.168053047203816
                -0.321696694921009  -0.621974427996805  0.168053047203816
                0.928618480068352  0.455124178121179  0.076169694452294
                0.928618480068352  -0.455124178121179  0.076169694452294
                -0.928618480068352  0.455124178121179  0.076169694452294
                -0.928618480068352  -0.455124178121179  0.076169694452294
                0.455124178121179  0.928618480068352  0.076169694452294
                0.455124178121179  -0.928618480068352  0.076169694452294
                -0.455124178121179  0.928618480068352  0.076169694452294
                -0.455124178121179  -0.928618480068352  0.076169694452294
                0.960457474887516  0.809863684081217  0.028794154400064
                0.960457474887516  -0.809863684081217  0.028794154400064
                -0.960457474887516  0.809863684081217  0.028794154400064
                -0.960457474887516  -0.809863684081217  0.028794154400064
                0.809863684081217  0.960457474887516  0.028794154400064
                0.809863684081217  -0.960457474887516  0.028794154400064
                -0.809863684081217  0.960457474887516  0.028794154400064
                -0.809863684081217  -0.960457474887516  0.028794154400064];

    else

        error('Precision not supported!')

    end

        x = xw(:,1:2);
        w = xw(:,3)/4;
        n = numel(w); 

end
