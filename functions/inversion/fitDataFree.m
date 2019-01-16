function [fitdata] = fitDataFree(time,signal,flag,parameter,nExp)
%fitDataFree is a control routine that uses 'lsqcurvefit' to fit NMR data
%with 'nExp' free relaxation times (T1 or T2)
%
% Syntax:
%       fitDataFree(time,signal,flag,parameter,nExp)
%
% InputsR:
%       time - time vector
%       signal - NMR signal vector (no complex data allowed!)
%       flag - either 'T1' or 'T2'
%       parameter - struct that hold additional settings:
%                   info : commandline output switch
%                   noise: NMR data noise
%       nExp - No. of free exponential(s)
%
% Outputs:
%       fitdata - struct that holds the inversion results:
%                   E0      : initial amplitude at t=0 (T2) or t=max (T1)
%                   T1 / T2 : relaxation time(s)
%                   fit_t   : time vector for plotting
%                   fit_s   : signal vector for plotting
%                   resnorm : residual norm (output from lsqcurvefit)
%                   residual: vector of residuals (output from lsqcurvefit)
%                   output  : output struct (output from lsqcurvefit)
%                   errnorm : error norm
%                   rms     : RMS error
%                   ci      : confidence intervall
%
% Example:
%       [fitdata] = fitDataFree(t,s,'T2',parameter,2)
%
% Other m-files required:
%       lsqcurvefit (Optimization Toolbox)
%       getFitErrors
%       fcn_fitFreeT1
%       fcn_fitFreeT1_fmin
%       fcn_fitFreeT2
%       fcn_fitFreeT2_fmin
%       fminsearchbnd
%       getConfInterval
%
% Subfunctions:
%       none
%
% MAT-files required:
%       none
%
% See also:
% Author: Thomas Hiller
% email: thomas.hiller[at]leibniz-liag.de
% License: MIT License (at end)

%------------- BEGIN CODE --------------

% make column vector
t = time(:);
s = signal(:);

% data noise
noise = parameter.noise;

% switch off output if no option is given via 'parameter'
if ~isfield(parameter,'info')
    parameter.info = 'off';
end

% start values for E and T
x0 = zeros(1,2*nExp);
for i = 1:nExp
    x0(2*i-1) = max(signal)/nExp;
    x0(2*i) = max(t)/4;
end

switch parameter.optim
    case 'on'
        % solver options
        options = optimset('Display',parameter.info,'MaxFunEvals',10^6,...
            'LargeScale','on','MaxIter',5000,'TolFun',1e-12,'TolX',1e-12);
        
        switch flag
            case 'T1'
                [x,~,~,~,output,~,jacobian] = lsqcurvefit(@fcn_fitFreeT1,...
                    x0,t,s,zeros(size(x0)),[],options);
            case 'T2'
                [x,~,~,~,output,~,jacobian] = lsqcurvefit(@fcn_fitFreeT2,...
                    x0,t,s,zeros(size(x0)),[],options);
        end
    case 'off'
        % solver options
        options = optimset('Display',parameter.info,'MaxFunEvals',10^6,...
            'MaxIter',5000,'TolFun',1e-12,'TolX',1e-12);
        
        switch flag
            case 'T1'
                [xsolve,~,~,output] = fminsearchbnd(@(x) fcn_fitFreeT1_fmin(x,t,s),...
                    x0,zeros(size(x0)),[],options);
            case 'T2'
                [xsolve,~,~,output] = fminsearchbnd(@(x) fcn_fitFreeT2_fmin(x,t,s),...
                    x0,zeros(size(x0)),[],options);
        end
        x = xsolve;
end

% get the fit
fit_t = t;
switch flag
    case 'T1'
        fit_s = fcn_fitFreeT1(x,fit_t);
    case 'T2'
        fit_s = fcn_fitFreeT2(x,fit_t);
end

% get residuals and error measures
out = getFitErrors(s,fit_s,noise);
switch parameter.optim
    case 'on'
        % nothing to do
    case 'off'
        % get Jacobian
        jacobian = getFitFreeJacobian(x,t,flag);
end
% confidence interval
ci = getConfInterval(out.resnorm,jacobian,0.05);

% sort the relaxation times in ascending order
E0 = x(1:2:end);
T = x(2:2:end);
[T,idx] = sort(T);
E0  = E0(idx);
ciT = ci(2:2:end);
ciE = ci(1:2:end);
ciT = ciT(idx);
ciE = ciE(idx);
ci(2:2:end) = ciT;
ci(1:2:end) = ciE;

% output struct
fitdata.E0 = E0;
switch flag
    case 'T1'
        fitdata.T1 = T;
    case 'T2'
        fitdata.T2 = T;
end
fitdata.fit_t = fit_t;
fitdata.fit_s = fit_s;
fitdata.resnorm = out.resnorm;
fitdata.residual = out.residual;
fitdata.errornorm = out.errnorm1;
fitdata.rms = out.rms;
fitdata.chi2 = out.chi2;
fitdata.ci = ci;
fitdata.x = x;
fitdata.output = output;

return

%------------- END OF CODE --------------

%% License:
% MIT License
%
% Copyright (c) 2018 Thomas Hiller
%
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in all
% copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.