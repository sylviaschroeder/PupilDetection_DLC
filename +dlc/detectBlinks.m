function [blinks, starts, stops] = detectBlinks(output, params, centerY, ...
    height, print)
%DETECTBLINKS   Detect blinks based on positions of detected markers
%   [BLINKS, STARTS, STOPS] = DETECTBLINKS(OUTPUT, PARAMS, CENTERY, HEIGHT, PRINT)
%   output      output table from DLC
%   params      struct;
%               .minCertainty: if DLC certainty above this threshold, 
%                   marker is assumed to be present in video frame
%               .lidMinStd: defines minimum distance between top and bottom 
%                   eye lid; if distance smaller the frame is counted as 
%                   blink
%               .minDistLidCenter: in number of pupil heights;  minimum 
%                   distance of top or bottom eye lid to centre of pupil;
%                   if smaller -> blink
%               .surroundingBlinks: number of frames before and after 
%                   detected blink that will also counted as blink
%   centerY     [t x 1]; vertical position of pupil centre
%   height      [t x 1]; pupil height
%   print       if true, prints blink intervals (in frames)
%
%   blinks      [t x 1]; true if blink, false otherwise
%   starts      [n x 1]; frame IDs when blink episodes start
%   stops       [n x 1]; frame IDs when blink episodes end

pupilTop = output(:,2:4); % [x y likelihood]
pupilBottom = output(:,5:7);
pupilLeft = output(:,8:10);
pupilRight = output(:,11:13);
lidTop = output(:,14:16);
lidBottom = output(:,17:19);

% blink if left or right pupil edges are uncertain
blinks = pupilLeft(:,3) < params.minCertainty | pupilRight(:,3) < params.minCertainty;

% blink if distance between upper and lower eye lids is very small
lidDistance = lidBottom(:,2) - lidTop(:,2);
lidValid = lidBottom(:,3) > params.minCertainty & lidTop(:,3) > params.minCertainty;
lidMean = mean(lidDistance(lidValid));
lidStd = std(lidDistance(lidValid));
blinks(lidValid) = blinks(lidValid) | lidDistance(lidValid) < ...
    lidMean - params.lidMinStd * lidStd;

% blink if top and bottom of pupil uncertain
blinks = blinks | (pupilTop(:,3) < params.minCertainty & ...
    pupilBottom(:,3) < params.minCertainty);

% blink if distance of center to lid (top or bottom) is too small
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

d = diff(blinks);
starts = find(d == 1) + 1;
if blinks(1)
    starts = [1; starts];
end
stops = find(d == -1);
if blinks(end)
    stops = [stops; length(blinks)];
end

if print
    fprintf('Blink episodes:\n')
    fprintf('  %d\t\t%d\n', [starts stops]')
end