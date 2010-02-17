function [w, sigma, logpostTrace]=linregFitSparseEm(X, y,  prior, scale, shape, sigma, varargin)
% Use EM to fit linear  regression  with sparsity promoting prior
% See the paper "Sparse Bayesian nonparametric regression"
% by F. Caron and A. Doucet, ICML2008.
% See also "Alternative prior distributions for variable selection
% with very many more variables than observations", Griffin and Brown, 2005
%
% The prior on each regresson weight is 
% p(w) = int N(w|0,tau) Gamma(tau | shape, scale) dtau
% This is a Normal-Gamma distribution.
% If shape=1, this induces a Laplace distribuiton
% If shape=scale=0, this induces Normal-Jeffreys distribution
%
%
% X: N*D design matrix 
% y:        data (vector of size N*1),
% sigma: if +ve, it is fixed at this value, if 0 it will be estimated
% prior: one of 'ng','laplace','nj','neg'
%
% Optional args
% maxIter - [300]
% verbose - [false]
%
% -- OUTPUTS --
%
% w     MAP estimate of weight vector 
% sigma     MLE of noise std dev
% logpostTrace   Objective vs iteration
% ---------------------------------
% Author: Francois Caron
% University of British Columbia
% Jan 30, 2008

%#author Francois Caron
% modified Kevin Murphy, 12 Nov 2009


warning off MATLAB:log:logOfZero
warning off MATLAB:divideByZero

[maxIter, verbose, convTol] = process_options(varargin, ...
   'maxIter', 300, 'verbose', false, 'convTol', 1e-5);

 if nargin <5, shape = 1; end
 if nargin < 6, sigma = -1; end
 
[N D]=size(X);
if sigma<0
   % sigma estimated
   computeSigma=1;
   sigma=-sigma;
else % sigma known
   computeSigma=0;
end

switch(prior)
  case 'ng'
    pen=@normalGammaNeglogpdf;
    diffpen=@normalGammaNeglogpdfDeriv;
    params = {shape, scale};
  case 'laplace'
    pen=@laplaceNeglogpdf;
    diffpen=@laplaceNeglogpdfDeriv;
    params = {scale^2/2}; % user specifies gamma
  case 'nj'
    pen=@normalJeffreysNeglogpdf;
    diffpen=@normalJeffreysNeglogpdfDeriv;
    params = {};
  case 'neg'
    pen=@normalExpGammaNeglogpdf;
    diffpen=@normalExpGammaNeglogpdfDeriv;
    params = {shape, scale};
  otherwise
    error(['unrecognized prior ' prior])
end

% Singular value decomposition to speed code
% - see Griffin and Brown, 2005, for details
[U S V]=svd(X);
ind=find(diag(S)>10^-10);
S=S(ind,ind);
U=U(:,ind);
V=V(:,ind);
Sinv = inv(S);
alpha_hat = Sinv*U'*y;
Si2 = S^-2;

if 1 % strcmp(model,'laplace') 
   computeLogpost = true;
else
   % cannot do it for normal gamma because prior is improper?
   computeLogpost = false;
end

logpdf=[];
w = pinv(X)*y;  % initialize from ridge
yhat = X*w;  se = (y-yhat).^2;
if computeSigma, sigma = sqrt(mean(var(se))); end
done = false;
iter = 1; 
while ~done
  wOld = w;
  sigmaOld = sigma;
  % E step
   % psi=diag(abs(wOld)./gamma); 
   %psi=diag(abs(wOld)./(gamma * sigmaOld)); % Park and Cassella '08
    psi=diag(abs(wOld)./diffpen(wOld,params{:}));
  % M step
  w = psi*V*inv((V'*psi*V+sigma^2*Si2))*alpha_hat;
  yhat = X*w;
  se = (y-yhat).^2;
  if computeSigma
    sigma = sqrt(mean(var(se)));
  end
  
  if computeLogpost
    NLL(iter)=N/2*log(sigma^2)+ sum(se)/(2*sigma^2) + sum(pen(w,params{:}));
    if iter>1
      if NLL(iter) > NLL(iter-1)
        error('EM did not decrease NLL')
      end
    end
  end
  if verbose% && (mod(iter,50)==0)
    if computeLogpost
      fprintf('iter %d, pen NLL = %5.3f\n', iter, NLL(iter))
    else
      fprintf('iter %d\n', iter)
    end
  end
  
  if iter>1
    converged = convergenceTest(NLL(iter), NLL(iter-1), convTol);
  else
    converged = false;
  end
  if isequal(w, wOld) || converged || (iter > maxIter)
    done = true;
  end
  iter = iter + 1;
end

logpostTrace = -NLL;

warning on MATLAB:log:logOfZero
warning on MATLAB:divideByZero

end

 





