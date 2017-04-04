function gobj = vis_csd(varargin)
% plot current source density for a signal object.
% Input:
%   hmObj:  Mobilab head model object associated with signal
%   signal: the data struction (must contain .chanlocs, .data, and .srcpot 
%           fields)
% Optional:
%   times:  vectors of times (in seconds) to plot. If > 1 a 'movie' is
%           generated
%   title:  figure title
%   pausedelay:  delay between frames (seconds)
%   clims:  color limits. If scalar, this is taken to be a percentile
%           over signal.srcpot. otherwise limits should be provided in 
%           [min max] form.
%
% Author: Tim Mullen, SCCN/INC/UCSD 2013

persistent hcb

% extract some defaults
headmodel_default = 'resources:/headmodels/standard-Colin27-385ch.mat';

g=arg_define([0 Inf],varargin, ...
    arg({'hmObj','HeadModelObject'},headmodel_default,[],'Head model object generated by MOBILAB. See MOBILAB''s headModel class.'), ...
    arg_norep({'signal','Signal'},[],[],'Signal structure. Must contain .srcpot field with csd and .data field with channel data'), ...
    arg_nogui({'cortexMesh','CortexMesh'},[],[],'Cortex mesh. Optional. Faces and vertices of a cortical surface mesh. This overrides the default mesh stored in hmObj'),...
    arg({'times','Times'},[],[],'Vector of times (in seconds) to plot. If length(times) > 1 a movie is generated'), ...
    arg({'avgtimes','AverageTimes'},false,[],'Average across times'), ...
    arg({'frameskip','FrameSkip'},2,[0 Inf],'Skip frames. Image will be generated every FramSkip frames'), ...
    arg({'title','Title'},'Current Source Density',[],'Figure title'), ...
    arg({'pausedelay','PauseDelay'},0,[0 Inf],'Delay between frames (seconds)'), ...
    arg({'cortexlims','CortexColorLimits'},'globalmaxabs',[],'Cortex color limits. Can be ''localmax'', ''globalmaxabs'', or numeric in [min max] form or a scalar, which is taken to be a percentile over signal.srcpot.','type','expression','shape','row'), ... 
    arg({'scalplims','ScalpColorLimits'},'globalmaxabs',[],'Scalp color limits. Can be ''localmax'', ''globalmaxabs'', or numeric in [min max] form or a scalar, which is taken to be a percentile over signal.data.','type','expression','shape','row'), ...
    arg({'showpower','ShowPower'},true,[],'Display power |CSD|^2'), ...
    arg({'pauseBehavior','PauseBehavior'},'return',{'return','hold'},'Pause behavior. Action to take when pause button is pressed'), ...
    arg_nogui({'gobj','GraphicsObject'},[],[],'Viewer Graphics Object. If empty a new figure is created. Otherwise, the graphics object is updated'));
  
arg_toworkspace(g);
times = g.times;
title = g.title;

hmObj = hlp_validateHeadModelObject(hmObj);

if ~isfield(signal,'srcpot_all')
    error('BCILAB:vis_csd:MissingSourcePotentials','signal does not contain field ''srcpot_all''. Please make sure ''KeepFullCsd'' option is enabled in SourceLocalization (flt_sourceLocalize)'); end

if isempty(times)
    times = linspace(signal.xmin,signal.xmax,signal.pnts);
elseif size(times,1) > size(times,2)
    times = times(:)';
end


hmObj = copy(hmObj);
tmp = hlp_microcache('loadsurf',@load,hmObj.surfaces);
surfData = tmp.surfData; clear tmp;

% overwrite the cortex surface
if ~isempty(g.cortexMesh)
    surfData(3) = g.cortexMesh;
end
% surfData(3) = signal.dipfit.reducedMesh;

if size(surfData(3).vertices,1)~=size(signal.srcpot_all,1)
    error('the number of vertices on the surface mesh (%d) does not equal the number of sources (rows of signal.srcpot_all) (%d)',size(surfData(3).vertices,1),size(signal.srcpot_all,1));
end

% match the headmodel electrodes with those in the signal
chanlabels = lower({signal.chanlocs.labels});
lookup = lower(hmObj.label);
% got channel names: look them up from the chanlocs, but ordered according to lookup
[x,a,b] = intersect(lookup,chanlabels); %#ok<ASGLU>
[x,I] = sort(a); remaining = b(I);
hmObj.label = hmObj.label(x);   
hmObj.channelSpace = hmObj.channelSpace(x,:);
signal.data = signal.data(remaining,:,:);

% convert times to samples
% FIXME: this assumes that xmin = 0. need to adjust for that
sampletimes = round((times-signal.xmin)*signal.srate)+1;
srcpot = signal.srcpot_all(:,sampletimes);
data   = signal.data(:,sampletimes);

if showpower
    % compute power
    srcpot = abs(srcpot).^2;
    data   = abs(data).^2;
end

if frameskip>0
    sampletimes = sampletimes(1:frameskip:end); end
if avgtimes
    srcpot = mean(srcpot,2);
    data   = mean(data,2);
    times  = mean(times);
    sampletimes = 1;
end

% translate the colorlimits
if ~(isnumeric(cortexlims) && length(cortexlims)==2)
    if isequal(cortexlims,'globalmaxabs') || isequal(cortexlims,100)
        mx = max(abs(srcpot(:)))+eps;
        cortexlims = [-mx mx]; 
    elseif isequal(cortexlims,'localmax')
        cortexlims = [];
    elseif isscalar(cortexlims)
        mx = prctile(srcpot(:),cortexlims)+eps;
        cortexlims = [-mx mx]; 
    end
end

if ~(isnumeric(scalplims) && length(scalplims)==2)
    if isequal(scalplims,'globalmaxabs') || isequal(scalplims,100)
        mx = max(abs(srcpot(:)))+eps;
        scalplims = [-mx mx]; 
    elseif isequal(scalplims,'localmax')
        scalplims = [];
    elseif isscalar(scalplims)
        mx = prctile(data(:),scalplims)+eps;
        scalplims = [-mx mx]; 
    end
end
        
        
% plot the surface
try
    for t=1:length(sampletimes)
        if isempty(gobj) && t==1
            % initialize figure
            gobj = currentSourceViewer(hmObj,srcpot(:,t),data(:,t),title,hmObj.label,[],surfData,cortexlims,times(t));

            [img_pause img_go] = hlp_microcache('viscsd',@loadimgs);
            toolbarHandle = findall(gobj.hFigure,'Type','uitoolbar');
            hcb = uitoggletool(toolbarHandle,'CData',img_pause,'Separator','off','HandleVisibility','off','TooltipString','Pause/Unpause','userData','go','State','off');
            set(hcb,'OnCallback', @(src,event) set(src,'userdata','pause','CData',img_go), ...
                    'OffCallback',@(src,event) set(src,'userdata','go','CData',img_pause));
        else
            if strcmp(get(hcb,'userdata'),'pause')
                if strcmp(g.pauseBehavior,'return')
                    return;
                elseif strcmp(g.pauseBehavior,'hold')
                    waitfor(hcb,'userdata','go');
                end
            end

            % update figure
            if ~ishandle(gobj.hFigure)
                return; 
            end

            if strcmp(get(gobj.hScalp,'visible'),'on')
                % use scalp colorlimits
                clims = scalplims;
            else
                clims = cortexlims;
            end

            try
                gobj = currentSourceViewer(hmObj,srcpot(:,t),data(:,t),title,hmObj.label,gobj,surfData,clims,times(t));
            catch err
                if strcmp(err.identifier,'MATLAB:class:InvalidHandle')
                    return; 
                end
            end
        end
        %     refresh(gobj.hFigure);
        if pausedelay > 0
            pause(pausedelay+eps);
        else
            drawnow;
        end
    
    end
catch err
    disp(err.message);
end

        
function [img_pause img_go] = loadimgs()
mPath = which('mobilabApplication');
path = fullfile(fileparts(mPath),'skin');
img_pause  = imread([path filesep '1339562143_player_pause.png']);
img_go = imread([path filesep '1339561905_player_play.png']);


