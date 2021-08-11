%% Folders
% folderData = 'J:\EyeData';
folderData = 'J:\EyeData\videos';
% folderSave = 'C:\STORAGE\OneDrive - University College London\Lab\DATA\DataToPublish\task2P';
% folderPlots = 'C:\STORAGE\OneDrive - University College London\Lab\RESULTS\wheelTask\pupil';
folderSave = 'C:\STORAGE\OneDrive - University of Sussex\Projects\2021_Joanna_competition in SC\Data';
folderPlots = 'C:\STORAGE\OneDrive - University of Sussex\Projects\2021_Joanna_competition in SC\Data\Pupil';
folderTools = 'C:\STORAGE\workspaces';
folderCode = 'C:\dev\workspace\CortexLab';

%% Add paths
addpath(genpath(fullfile(folderTools, 'npy-matlab')))
addpath(genpath(fullfile(folderCode)))

%% Parameters
params.minCertainty = 0.6;
params.lidMinStd = 7;
params.minDistLidCenter = 0.5; % in number of pupil heights
params.surroundingBlinks = 5; % in frames
params.interpMethod = 'linear';
params.maxDistPupilLid = 10; % in pixels
params.smoothSpan = 5; % in frames

%% Database
% db_wheelTask
db = db_ephys_task;

%% for ephys data
for k = 20:length(db)
    fprintf('%s %s\n', db(k).subject, db(k).date)
    %% Import data, plot basic relationships
    file = dir(fullfile(folderData, sprintf('%s_*_%s_*.csv',db(k).date, db(k).subject)));
    output = readmatrix(fullfile(folderData, file.name));
    
    pupilTop = output(:,2:4); % [x y likelihood]
    pupilBottom = output(:,5:7);
    pupilRight = output(:,8:10);
    pupilLeft = output(:,11:13);
    lidTop = output(:,14:16);
    lidBottom = output(:,17:19);
    data = [pupilTop, pupilBottom, pupilLeft, pupilRight, lidTop, lidBottom];
    
    % relation between horizontal pupil position, and width and height of pupil
    width = pupilRight(:,1) - pupilLeft(:,1);
    height = pupilBottom(:,2) - pupilTop(:,2);
    centerX = pupilLeft(:,1) + 0.5 .* width;
    valid = all(data(:, 3:3:12) > params.minCertainty, 2);
    
    [F, F0] = dlc.estimateHeightFromWidthPos(width(valid), height(valid), ...
        centerX(valid), params);
    
    [centerY_adj, height_adj] = dlc.adjustCenterHeight(data, F, params);
    
    [blinks, blStarts, blStops] = dlc.detectBlinks(data, params, ...
        centerY_adj, height_adj, true);
    
    centerX = medfilt1(centerX, params.smoothSpan);
    centerY_adj = medfilt1(centerY_adj, params.smoothSpan);
    center = [centerX, centerY_adj];
    center(blinks,:) = NaN;
    height_adj = medfilt1(height_adj, params.smoothSpan);
    diameter = height_adj;
    diameter(blinks) = NaN;
    
    % save data
    fs = fullfile(folderSave, db(k).subject, db(k).date);
    if ~isfolder(fs)
        mkdir(fs)
    end
    writeNPY(center, fullfile(fs, 'eye.xyPos.npy'));
    writeNPY(diameter, fullfile(fs, 'eye.diameter.npy'));
    
    %% Plot data
    fs = fullfile(folderPlots, db(k).subject, db(k).date);
    if ~isfolder(fs)
        mkdir(fs)
    end
    
    % scatter: width vs height of pupil (horizontal position of pupil color
    % coded)
    mini = min([width(~blinks); height(~blinks)]);
    maxi = max([width(~blinks); height(~blinks)]);
    figure('Position', [13 570 560 420])
    hold on
    plot([mini maxi], [mini maxi], 'r')
    scatter(width(~blinks), height(~blinks), 10, centerX(~blinks), 'filled', ...
        'MarkerFaceAlpha', 0.3)
    axis square
    colormap jet
    xlabel('Pupil width')
    ylabel('Pupil height')
    c = colorbar;
    c.Label.String = 'Horizontal position';
    axis tight
    saveas(gcf, fullfile(fs, 'scatter_width-height.png'))
    
    % relation: dependence of pupil height (color coded) on pupil width (y) and
    % horizontal position of pupil (x)
    [x,y] = meshgrid(linspace(min(centerX(~blinks)),max(centerX(~blinks)),100), ...
        linspace(min(width(~blinks)),max(width(~blinks)),100));
    z0 = F0(x,y);
    figure('Position', [585 570 560 420])
    imagesc(x([1 end]),y([1 end]),z0)
    set(gca, 'YDir', 'normal')
    colormap jet
    xlabel('Horizontal pupil position')
    ylabel('Pupil width')
    c = colorbar;
    c.Label.String = 'Pupil height';
    title('Interpolation between variables')
    saveas(gcf, fullfile(fs, 'surface_centerX-height.png'))
    
    % above relation smoothed
    z = F(x(:), y(:));
    z = reshape(z,100,100);
    z(isnan(z0)) = NaN;
    figure('Position', [1155 570 560 420])
    imagesc(x([1 end]), y([1 end]), z)
    colormap jet
    set(gca, 'YDir', 'normal')
    colorbar
    xlabel('Horizontal pupil position')
    ylabel('Pupil width')
    c = colorbar;
    c.Label.String = 'Pupil height';
    title('Function used to estimate pupil height from width')
    saveas(gcf, fullfile(fs, 'surfaceSmooth_centerX-height.png'))
    
    % center of pupil (x and y) and pupil diameter, blinks marked
    figure('Position', [6 50 1915 455])
    ax = [0 0 0];
    data = [centerX, centerY_adj, height_adj];
    names = {'center x', 'center y', 'diameter'};
    for s = 1:3
        mini = min(data(~blinks,s));
        maxi = max(data(~blinks,s));
        rng = maxi - mini;
        mini = mini - 0.02*rng;
        maxi = maxi + 0.02*rng;
        subplot(3,1,s)
        hold on
        if ~isempty(blStarts)
            fill([blStarts'; blStops'; blStops'; blStarts'], ...
                [[1 1]' .* mini; [1 1]' .* maxi], 'k', ...
                'FaceColor', [1 1 1].*0.5, 'EdgeColor', 'none')
        end
        plot(data(:,s), 'k')
        ylim([mini maxi])
        ax(s) = gca;
        ylabel(names{s})
    end
    xlabel('frames')
    linkaxes(ax, 'x')
    xlim([1 size(data,1)])
    savefig(fullfile(fs, 'lines_center-diameter.fig'))
    saveas(gcf, fullfile(fs, 'lines_center-diameter.png'))
    
%     pause
    
    close all
end


%% for 2P data
% for k = 1:length(db)
%     for exp = 1:length(db(k).exp)
%         fprintf('%s %s exp %d\n', db(k).subject, db(k).date, db(k).exp(exp))
%         %% Import data, plot basic relationships
%         folder = fullfile(folderData, db(k).subject, db(k).date, num2str(db(k).exp(exp)));
%         file = dir(fullfile(folder, '*.csv'));
%         output = readmatrix(fullfile(folder, file.name));
%         
%         pupilTop = output(:,2:4); % [x y likelihood]
%         pupilBottom = output(:,5:7);
%         pupilLeft = output(:,8:10);
%         pupilRight = output(:,11:13);
%         lidTop = output(:,14:16);
%         lidBottom = output(:,17:19);
%         
%         % relation between horizontal pupil position, and width and height of pupil
%         width = pupilRight(:,1) - pupilLeft(:,1);
%         height = pupilBottom(:,2) - pupilTop(:,2);
%         centerX = pupilLeft(:,1) + 0.5 .* width;
%         valid = all(output(:,4:3:end) > params.minCertainty, 2);
%         
%         [F, F0] = dlc.estimateHeightFromWidthPos(width(valid), height(valid), ...
%             centerX(valid), params);
%         
%         [centerY_adj, height_adj] = dlc.adjustCenterHeight(output, F, params);
%         
%         [blinks, blStarts, blStops] = dlc.detectBlinks(output, params, ...
%             centerY_adj, height_adj, true);
%         
%         centerX = medfilt1(centerX, params.smoothSpan);
%         centerY_adj = medfilt1(centerY_adj, params.smoothSpan);
%         center = [centerX, centerY_adj];
%         center(blinks,:) = NaN;
%         height_adj = medfilt1(height_adj, params.smoothSpan);
%         diameter = height_adj;
%         diameter(blinks) = NaN;
%         
%         % save data
%         fs = fullfile(folderSave, db(k).subject, db(k).date, num2str(exp));
%         if ~isfolder(fs)
%             mkdir(fs)
%         end
%         writeNPY(center, fullfile(fs, 'eye.xyPos.npy'));
%         writeNPY(diameter, fullfile(fs, 'eye.diameter.npy'));
%         
%         %% Plot data
%         fs = fullfile(folderPlots, db(k).subject, db(k).date, num2str(exp));
%         if ~isfolder(fs)
%             mkdir(fs)
%         end
%         
%         % scatter: width vs height of pupil (horizontal position of pupil color
%         % coded)
%         mini = min([width(~blinks); height(~blinks)]);
%         maxi = max([width(~blinks); height(~blinks)]);
%         figure('Position', [13 570 560 420])
%         hold on
%         plot([mini maxi], [mini maxi], 'r')
%         scatter(width(~blinks), height(~blinks), 10, centerX(~blinks), 'filled', ...
%             'MarkerFaceAlpha', 0.3)
%         axis square
%         colormap jet
%         xlabel('Pupil width')
%         ylabel('Pupil height')
%         c = colorbar;
%         c.Label.String = 'Horizontal position';
%         axis tight
%         savefig(fullfile(fs, 'scatter_width-height.fig'))
%         saveas(gcf, fullfile(fs, 'scatter_width-height.png'))
%         
%         % relation: dependence of pupil height (color coded) on pupil width (y) and
%         % horizontal position of pupil (x)
%         [x,y] = meshgrid(linspace(min(centerX(~blinks)),max(centerX(~blinks)),100), ...
%             linspace(min(width(~blinks)),max(width(~blinks)),100));
%         z0 = F0(x,y);
%         figure('Position', [585 570 560 420])
%         imagesc(x([1 end]),y([1 end]),z0)
%         set(gca, 'YDir', 'normal')
%         colormap jet
%         xlabel('Horizontal pupil position')
%         ylabel('Pupil width')
%         c = colorbar;
%         c.Label.String = 'Pupil height';
%         title('Interpolation between variables')
%         savefig(fullfile(fs, 'surface_centerX-width-height.fig'))
%         saveas(gcf, fullfile(fs, 'surface_centerX-height.png'))
%         
%         % above relation smoothed
%         z = F(x(:), y(:));
%         z = reshape(z,100,100);
%         z(isnan(z0)) = NaN;
%         figure('Position', [1155 570 560 420])
%         imagesc(x([1 end]), y([1 end]), z)
%         colormap jet
%         set(gca, 'YDir', 'normal')
%         colorbar
%         xlabel('Horizontal pupil position')
%         ylabel('Pupil width')
%         c = colorbar;
%         c.Label.String = 'Pupil height';
%         title('Function used to estimate pupil height from width')
%         savefig(fullfile(fs, 'surfaceSmooth_centerX-width-height.fig'))
%         saveas(gcf, fullfile(fs, 'surfaceSmooth_centerX-height.png'))
%         
%         % center of pupil (x and y) and pupil diameter, blinks marked
%         figure('Position', [6 50 1915 455])
%         ax = [0 0 0];
%         data = [centerX, centerY_adj, height_adj];
%         names = {'center x', 'center y', 'diameter'};
%         for s = 1:3
%             mini = min(data(~blinks,s));
%             maxi = max(data(~blinks,s));
%             rng = maxi - mini;
%             mini = mini - 0.02*rng;
%             maxi = maxi + 0.02*rng;
%             subplot(3,1,s)
%             hold on
%             if ~isempty(blStarts)
%                 fill([blStarts'; blStops'; blStops'; blStarts'], ...
%                     [[1 1]' .* mini; [1 1]' .* maxi], 'k', ...
%                     'FaceColor', [1 1 1].*0.8, 'EdgeColor', 'none')
%             end
%             plot(data(:,s), 'k')
%             ylim([mini maxi])
%             ax(s) = gca;
%             ylabel(names{s})
%         end
%         xlabel('frames')
%         linkaxes(ax, 'x')
%         xlim([1 size(data,1)])
%         savefig(fullfile(fs, 'lines_center-diameter.fig'))
%         saveas(gcf, fullfile(fs, 'lines_center-diameter.png'))
%         
%         pause
%         
%         close all
%     end
% end