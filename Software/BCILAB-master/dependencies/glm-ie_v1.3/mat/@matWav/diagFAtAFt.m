% 2d wavelet transform matrix: (real) diagonal in Fourier space of A'*A
%
% (c) by Hannes Nickisch, MPI for Biological Cybernetics, 2010 October 12

function d = diagFAtAFt(A)

  d = ones(A.imsz);