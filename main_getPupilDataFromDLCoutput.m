%% Folders
folderData = 'Z:\UCLData\2P_Task';
folderSave = 'Z:\UCLData\2P_Task';
folderPlots = 'C:\Users\Sylvia\OneDrive - University of Sussex\Lab\RESULTS\wheelTask\pupil';
folderTools = 'C:\dev\toolboxes';
folderCode = 'C:\dev\workspaces\CortexLab';

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

dataInSubfolders = true;
savePerExp = true;

%% Database
db_wheelTask % creates structure db with fields: .subject (animal name), .date

%% Extract and save pupil height
for k = 1:length(db)
    if savePerExp
        exps = db(k).expNoise;
    else
        exps = [1];
    end
    for exp = 1:length(exps)
        fprintf('%s %s exp %d\n', db(k).subject, db(k).date, exps(exp))
        %% Import data, plot basic relationships
        if dataInSubfolders
            folder = fullfile(folderData, db(k).subject, db(k).date, num2str(exps(exp)));
            file = dir(fullfile(folder, '*.csv'));
        else
            folder = folderData;
            file = dir(fullfile(folderData, sprintf('%s_*_%s_*.csv',db(k).date, db(k).subject)));
        end
        output = readmatrix(fullfile(folder, file.name));
        output(:,[1 (20:end)]) = [];
        
        pupilTop = output(:,1:3); % [x y likelihood]
        pupilBottom = output(:,4:6);
        pupilRight = output(:,7:9);
        pupilLeft = output(:,10:12);
        lidTop = output(:,13:15);
        lidBottom = output(:,16:18);
        
        % relation between horizontal pupil position, and width and height of pupil
        width = pupilRight(:,1) - pupilLeft(:,1);
        height = pupilBottom(:,2) - pupilTop(:,2);
        centerX = pupilLeft(:,1) + 0.5 .* width;
        valid = all(output(:,3:3:end) > params.minCertainty, 2);
        
        [F, F0] = dlc.estimateHeightFromWidthPos(width(valid), height(valid), ...
            centerX(valid), params);
        
        [centerY_adj, height_adj] = dlc.adjustCenterHeight(output, F, params);
        
        [blinks, blStarts, blStops] = dlc.detectBlinks(output, params, ...
            centerY_adj, height_adj, true);
        
        centerX = medfilt1(centerX, params.smoothSpan);
        centerY_adj = medfilt1(centerY_adj, params.smoothSpan);
        center = [centerX, centerY_adj];
        center(blinks,:) = NaN;
        height_adj = medfilt1(height_adj, params.smoothSpan);
        diameter = height_adj;
        diameter(blinks) = NaN;
        
        % save data
        if savePerExp
            fs = fullfile(folderSave, db(k).subject, db(k).date, num2str(exps(exp)));
        else
            fs = fullfile(folderSave, db(k).subject, db(k).date);
        end
        if ~isfolder(fs)
            mkdir(fs)
        end
        writeNPY(center, fullfile(fs, 'eye.xyPos.npy'));
        writeNPY(diameter, fullfile(fs, 'eye.diameter.npy'));
        
        %% Plot data
        if savePerExp
            fs = fullfile(folderPlots, db(k).subject, db(k).date, num2str(exp));
        else
            fs = fullfile(folderPlots, db(k).subject, db(k).date);
        end
        if ~isfolder(fs)
            mkdir(fs)
        end
        
        % scatter: horizontal position of pupil vs width (height of pupil color
        % coded)
        figure('Position', [13 570 560 420])
        scatter(centerX(valid), width(valid), 10, height(valid), 'filled', ...
            'MarkerFaceAlpha', 0.3)
        colormap jet
        xlabel('Horizontal pupil position')
        ylabel('Pupil width')
        c = colorbar;
        c.Label.String = 'Pupil height';
        axis tight
%         savefig(fullfile(fs, 'scatter_width-height.fig'))
        saveas(gcf, fullfile(fs, 'scatter_centerX-width.png'))
        
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
%         savefig(fullfile(fs, 'surface_centerX-width-height.fig'))
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
%         savefig(fullfile(fs, 'surfaceSmooth_centerX-width-height.fig'))
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
                    'FaceColor', [1 1 1].*0.8, 'EdgeColor', 'none')
            end
            plot(data(:,s), 'k')
            ylim([mini maxi])
            ax(s) = gca;
            ylabel(names{s})
        end
        xlabel('frames')
        linkaxes(ax, 'x')
        xlim([1 size(data,1)])
%         savefig(fullfile(fs, 'lines_center-diameter.fig'))
        saveas(gcf, fullfile(fs, 'lines_center-diameter.png'))
        
        pause
        
        close all
    end
end