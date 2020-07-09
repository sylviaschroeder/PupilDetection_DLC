function [blinks, starts, stops] = detectBlinks(output, params, centerY, ...
    height, print)

pupilTop = output(:,2:4); % [x y likelihood]
pupilBottom = output(:,5:7);
pupilLeft = output(:,8:10);
pupilRight = output(:,11:13);
lidTop = output(:,14:16);
lidBottom = output(:,17:19);

blinks = pupilLeft(:,3) < params.minCertainty | pupilRight(:,3) < params.minCertainty;

% distance between upper and lower eye lids is very small
lidDistance = lidBottom(:,2) - lidTop(:,2);
lidValid = lidBottom(:,3) > params.minCertainty & lidTop(:,3) > params.minCertainty;
lidMean = mean(lidDistance(lidValid));
lidStd = std(lidDistance(lidValid));
blinks(lidValid) = blinks(lidValid) | lidDistance(lidValid) < ...
    lidMean - params.lidMinStd * lidStd;

% if top and bottom of pupil uncertain -> blink
blinks = blinks | (pupilTop(:,3) < params.minCertainty & ...
    pupilBottom(:,3) < params.minCertainty);

% get minimum distance of center to lid (top or bottom); if distance too 
% small -> blink
distLidCenter = min([lidBottom(:,2) - centerY, centerY - lidTop(:,2)], [], 2);
blinks = blinks | distLidCenter < params.minDistLidCenter * height;

% % disregard single detected frames
% single = all([blinks, [false; ~blinks(1:end-1)], [~blinks(2:end); false]], 2);
% blinks(single) = false;

% include n frames before and after detected blinks
tmp = blinks;
for t = 1:params.surroundingBlinks
    blinks = blinks | [false(t,1); tmp(1:end-t)];
    blinks = blinks | [tmp(1+t:end); false(t,1)];
end

if print
    d = diff(blinks);
    starts = find(d == 1) + 1;
    if blinks(1)
        starts = [1; starts];
    end
    stops = find(d == -1);
    if blinks(end)
        stops = [stops; length(blinks)];
    end
    fprintf('Blink episodes:\n')
    fprintf('  %d\t\t%d\n', [starts stops]')
end