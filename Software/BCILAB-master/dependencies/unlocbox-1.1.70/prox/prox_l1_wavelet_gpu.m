function [sol,iter] = prox_l1_wavelet_gpu(x, gamma, param)
%PROX_L1 Proximal operator with L1 norm
%   Usage:  sol=prox_l1(x, gamma)
%           sol=prox_l1(x, gamma, param)
%           [sol, iter]=prox_l1(x, gamma, param)
%
%   Input parameters:
%         x     : Input signal.
%         gamma : Regularization parameter.
%         param : Structure of optional parameters.
%   Output parameters:
%         sol   : Solution.
%         iter  : Number of iterations at convergence.
%
%   prox_l1(x, gamma, param) solves:
%
%      sol = argmin_{z} 0.5*||x - z||_2^2 + gamma  |A Z|1
%
%
%   param is a Matlab structure containing the following fields:
%
%    param.A : Forward operator (default: Id).
%
%    param.At : Adjoint operator (default: Id).
%
%    param.tight : 1 if A is a tight frame or 0 if not (default = 1)
%
%    param.nu : bound on the norm of the operator A (default: 1), i.e.
%
%        ` ||A x||^2 <= nu  ||x||^2 
%
%   
%    param.tol : is stop criterion for the loop. The algorithm stops if
%
%         (  n(t) - n(t-1) )  / n(t) < tol,
%      
%
%     where  n(t) = f(x)+ 0.5 X-Z2^2 is the objective function at iteration t*
%     by default, tol=10e-4.
%
%    param.maxit : max. nb. of iterations (default: 200).
%
%    param.verbose : 0 no log, 1 a summary at convergence, 2 print main
%     steps (default: 1)
%
%    param.weights : weights for a weighted L1-norm (default = 1)
%
%   See also:  proj_b1 prox_l1inf prox_l12 prox_tv
%
%   References:
%     M. Fadili and J. Starck. Monotone operator splitting for optimization
%     problems in sparse recovery. In Image Processing (ICIP), 2009 16th IEEE
%     International Conference on, pages 1461-1464. IEEE, 2009.
%     
%     A. Beck and M. Teboulle. A fast iterative shrinkage-thresholding
%     algorithm for linear inverse problems. SIAM Journal on Imaging
%     Sciences, 2(1):183-202, 2009.
%
%   Url: http://unlocbox.sourceforge.net/doc/prox/prox_l1_wavelet_gpu.php

% Copyright (C) 2012 LTS2-EPFL, by Nathanael Perraudin, Gilles Puy,
% David Shuman, Pierre Vandergheynst.
% This file is part of UnLocBoX version 1.1.70
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.


% Author: Gilles Puy, Nathanael Perraudin
% Date: Nov 2012
%

% Optional input arguments
if nargin<3, param=struct; end

% Optional input arguments
if ~isfield(param, 'verbose'), param.verbose = 1; end
if ~isfield(param, 'tight'), param.tight = 1; end
if ~isfield(param, 'nu'), param.nu = 1; end
if ~isfield(param, 'tol'), param.tol = 1e-3; end
if ~isfield(param, 'maxit'), param.maxit = 200; end
if ~isfield(param, 'At'), param.At = @(x) x; end
if ~isfield(param, 'A'), param.A = @(x) x; end
if ~isfield(param, 'weights'), param.weights = 1; end
if ~isfield(param, 'pos'), param.pos = 0; end

% test the parameters
gamma=test_gamma(gamma);
param.weights=test_weights(param.weights);

% Useful functions

    % This soft thresholding function only support real signal
    % soft = @(z, T) sign(z).*max(abs(z)-T, 0);

    % This soft thresholding function support complex number
    soft = @(z, T) max(abs(z)-T,0)./(max(abs(z)-T,0)+T).*z;


% Projection
if param.tight && ~param.pos % TIGHT FRAME CASE
    
    temp = param.A(x);
    sol = x + 1/param.nu * param.At(soft(temp, ...
        gamma*param.nu*param.weights)-temp);
    crit_L1 = 'REL_OBJ'; iter_L1 = 1;
    dummy = param.A(sol);
    norm_l1 = sum(param.weights(:).*abs(dummy(:)));

else % NON TIGHT FRAME CASE OR CONSTRAINT INVOLVED
    % Initializations - The original code takes significant time and
    % should either be optimized (as below) or moved to the GPU.
    % Original code:
    %   u_l1 = zeros(size(param.Psit(x)));
    %   sol = x - param.Psi(u_l1);
    % Optimized code:
    u_l1 = zeros(size(x));
    sol = x;

    prev_l1 = 0; iter_L1 = 0;
    
    % Soft-thresholding
    % Init
    if param.verbose > 1
        fprintf('  Proximal l1 operator:\n');
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Eyal: input should not be complex.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    sol = real(sol);
    x = real(x);

    Depth = 1;
    Width  = size(sol, 1);
    Height = size(sol, 2);
    qmfSize = size(param.h, 2);
    result=single(ones(size(sol)));
    result_ptr = libpointer('singlePtr', result);
    x_ptr = libpointer('singlePtr', single(x));
    sol_ptr = libpointer('singlePtr', single(sol));
    u_l1_ptr = libpointer('singlePtr', single(u_l1));
    qmf_ptr = libpointer('singlePtr', single(param.h));
    
    calllib('gpuImgLib','ProxL1', result_ptr, x_ptr, sol_ptr, u_l1_ptr, ...
               Width, Height, Depth, gamma, param.weights, param.nu, param.tol, param.maxit, param.pos, param.L, qmf_ptr, qmfSize);
    sol = reshape(result_ptr.Value, [Width Height Depth]);
    
    % dummy values as we don't have it for the GPU.
    norm_l1 = 999.9;
    crit_L1 = 999.9;
    iter_L1 = 999.9;    
end

% Log after the projection onto the L2-ball
if param.verbose >= 1
    fprintf(['  prox_L1: ||A x||_1 = %e,', ...
        ' %s, iter = %i\n'], norm_l1, crit_L1, iter_L1);
end
iter=iter_L1;
end
