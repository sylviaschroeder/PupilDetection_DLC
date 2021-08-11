function [F, F0] = estimateHeightFromWidthPos(width, height, centerX, params)

F0 = scatteredInterpolant(centerX, width, height, ...
    params.interpMethod, 'none');
[x,y] = meshgrid(linspace(min(centerX),max(centerX),100), ...
    linspace(min(width),max(width),100));
z0 = F0(x,y);

ind = ~any(isnan([x(:), y(:), z0(:)]), 2);
F = fit([x(ind), y(ind)], z0(ind), 'lowess', 'Span', 0.1);