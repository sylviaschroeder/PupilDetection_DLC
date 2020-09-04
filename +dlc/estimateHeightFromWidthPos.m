function [F, F0] = estimateHeightFromWidthPos(width, height, centerX, params)
%ESTIMATEHEIGHTFROMWIDTHPOS Fits a smooth surface to estimate pupil height
%given pupil width and position.
%   [F, F0] = ESTIMATEHEIGHTFROMWIDTHPOS(width, height, centerX, params)
%   width     [t x 1], pupil width
%   height    [t x 1], pupil height
%   centerX   [t x 1], position of centre of pupil in x (horizontal)
%   params    struct, params.interpMethod = 'nearest', 'linear', or 'natural'
%
%   F         smoothed surface: F(centerX, width) = height
%   F0        interpolated surface: F0(centerX, width) = height

F0 = scatteredInterpolant(centerX, width, height, ...
    params.interpMethod, 'none');
[x,y] = meshgrid(linspace(min(centerX),max(centerX),100), ...
    linspace(min(width),max(width),100));
z0 = F0(x,y);

ind = ~any(isnan([x(:), y(:), z0(:)]), 2);
F = fit([x(ind), y(ind)], z0(ind), 'lowess', 'Span', 0.1);