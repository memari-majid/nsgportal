% pop_nsg() - Manage interface EEGLAB-NSG from GUI and command line calls
%
% Usage: 
%             >> [currentjob, alljobs, com] = pop_nsg;  % Call GUI  
%             >> [currentjob, alljobs, com] = pop_nsg('optname', optarg); % Command line call
%
% Command line options :
% These options must be provided as a single pair ('optname', optarg) per call
%   'test'      - Perform test on the .zip or folder provided as argument.
%   'output'    - Retrieve the output files of the job identifier or job 
%                 structure  provided as argument
%   'delete'    - Delete job  associated to job identifier or job structure 
%                 provided as argument
%   'run'       - Submit .zip or folder provided as argument to run on NSG.
% 
% Optional inputs:
%   'jobid'           - String with the client job id. This was assigned to the
%                       job when created. Use with command line option option 'run'. 
%                       Default: None
%   'outfile'         - String with the name of the results file. 
%                       Default: ['nsgresults_' jobname] . Jobname here is the
%                       name of the file submitted. Use with command line option 
%                       option 'run'. 
%   'runtime'         - Time (in hours) to allocate for running the job in NSG. 
%                       Maximun time allocation is 48 hrs. Use with command line 
%                       option option 'run'. Default: 0.5
%   'filename'        - Name of main file to run in NSG. Default: 'test.m'
%                       Use with command line option option 'run'.
%   'subdirname'      - Name of Sub-directory containing the main file i.e. if
%                       your main file is not on the top level directory. Use
%                       with command line option option 'run'. Default: None
%
% Outputs:
%   currentjob  - When pop_nsg is called from the command line (see Command line  
%                 options above), this output will return the job object of the 
%                 job manipulated. When called from GUI this output will be the 
%                 job object of the job selected in the user interface.
%   alljobs     - Structre with the all the job objects currently in NSG
%                 under your credentials
%   com         - Commands for EEG history
%   
%  See also: nsg_delete(), nsg_jobs(), nsg_test(), nsg_run()
%
% Authors: Arnaud Delorme, Ramon Martinez-Cancino, SCCN/INC/UCSD 2019

% Copyright (C) Arnaud Delorme
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

function [currentjob, alljobs, com] = pop_nsg(fig, str, varargin)
currentjob = []; alljobs = []; com = '';

try
    options = varargin;
    if ~isempty( varargin )
        if ~ischar(options{1}), options = options{1}; end
        for i = 1:2:numel(options)
            g.(options{i}) = options{i+1};
        end
    else, g= []; end
catch
    disp('pop_nsg() error: calling convention {''key'', value, ... } error'); return;
end

try g.listvalue;        catch, g.listvalue       = [] ;          end
try g.jobid;            catch, g.jobid           = '';          end
try g.outfile;          catch, g.outfile         = '';          end % Default defined in nsg_run
try g.runtime;          catch, g.runtime         = 0.5;         end
try g.filename;         catch, g.filename        = {''};        end
try g.subdirname;       catch, g.subdirname      = '';          end

% Internet checking
if ~nsg_checknet
    error('pop_nsg: Unable to establish a connection to ''www.nsgportal.org'' ');
end

if nargin < 1
    
    % Closing open GUI and creating a new one
    openfig = findobj('tag', 'pop_nsg');
    if ~isempty(openfig)
        disp('pop_nsg warning: there can be only one pop_nsg window, closing old one...')
        close(openfig); 
    end
    fig = figure('visible', 'off','Units', 'Normalized', 'Tag', 'pop_nsg','visible','off' ); % create figure
    
    % Callbacks
    res = nsg_jobs;
    if isfield(res, 'error')
        errordlg2(res.error.message);
        error(res.error.message);
    end
    
    jobstruct    = backupjobstatus(res);
    jobnames     = {jobstruct.dispname};
    cbloadplot   = 'pop_nsg(gcbf,''loadplot'');';
    cbcancel     = 'timerobjtmp = timerfindall(''Tag'',''nsg_autorescantimer''); if ~isempty(timerobjtmp), stop(timerobjtmp); delete(timerobjtmp); end; close(gcbf);';
    cblist       = 'pop_nsg(gcbf,''update'');';
    cbstdout     = 'pop_nsg(gcbf,''stdout'');';
    cbstderr     = 'pop_nsg(gcbf,''stderr'');';
    cbrescan     = 'pop_nsg(gcbf,''rescan'');';
    cbarescan    = 'pop_nsg(gcbf,''autorescan'');';
    cbtest       = 'pop_nsg(gcbf,''testgui'');';
    cboutput     = 'pop_nsg(gcbf,''outputgui'');';
    cdelete      = 'pop_nsg(gcbf,''deletegui'');';
    cbrun        = 'pop_nsg(gcbf,''rungui'',eval( [ ''{'' get(findobj(gcf,''tag'',''edit_runopt''),''string'') ''}'' ] ));';
    cbsetmfile   = 'jobfile = get(findobj(gcbf,''tag'',''fileorfolder''),''String''); mfilelist = '' '';if ~isempty(jobfile),if isdir(jobfile),mfilestmp = dir(fullfile(jobfile, ''*.m''));if ~isempty(mfilestmp), mfilelist = {mfilestmp.name}; end;else,mfilelist = listzipcontents(jobfile, ''.m'');if isempty(mfilelist), mfilelist = '' ''; end; end;set(findobj(gcbf,''tag'',''listbox_mfile''),''string'',mfilelist,''Value'', 1);end;clear pathname filename;';
    cbsetjobid   = 'if ~isequal(pathname, 0), [tmp, filenamenoext]= fileparts(filename); set(findobj(gcf,''tag'',''edit_jobid''),''string'',[filenamenoext num2str(ceil(1000*rand(1)))]);clear filenamenoext;end;';
    cbload       =  ['ButtonName = questdlg2(''Do you want to load a ZIP file or a folder?'',''pop_nsg'',''Folder'', ''ZIP File'', ''ZIP File'');if strcmpi(ButtonName, ''zip file''),[filename pathname] = uigetfile({''*.zip'' ''*.ZIP''});if ~isequal(pathname, 0),set(findobj(gcbf, ''tag'', ''fileorfolder''), ''string'', fullfile(pathname, filename));end;else,pathname = uigetdir();[trash,filename] = fileparts(pathname);if ~isequal(pathname, 0),set(findobj(gcbf, ''tag'', ''fileorfolder''), ''string'', pathname);end;end;' cbsetjobid cbsetmfile];
    cbmfileset   =  'jobfile = get(findobj(gcbf,''tag'',''fileorfolder''),''String'');if ~isempty(jobfile), [tmp, filenamenoext]=fileparts(jobfile); set(findobj(gcf,''tag'',''edit_jobid''),''string'',[filenamenoext num2str(ceil(1000*rand(1)))]);clear filenamenoext;end;';
    joblog       = char(ones(7,70)*' ');
    
    % Tooltips
    ttjobs     = 'List of all jobs under your username in NSG';
    ttrefresh  = 'Refresh the list of all of your NSG jobs';
    ttarefresh = 'Automatically refresh the list of all of your NSG jobs';
    ttdelete   = 'Delete the currently selected job';
    ttoutlog   = 'Download and display MATLAB command line output for the currently selected job';
    tterrlog   = 'Download and display the MATLAB error log for the currently selected job';
    ttresults  = 'Download result files from the currently selected job';
    ttload     = 'Launch a GUI for loading and displaying results of the currently selected job';
    ttfile     = 'Full path to the zip file or folder for a job to submit to NSG';
    ttbrowse   = 'Browse a zip file or folder for a job to submit to NSG';
    ttmatfile  = 'Matlab script for NSG to execute upon job submission';
    tttest     = ['Test job locally on this computer.' , char(10), ...
                 'Warning: Test a downscaled version of the job using a scaled down script.', char(10), ...
                 'Example: Instead of ''for block=1:N'', in the test script use ''for block=1:1'''];
    ttjobid    = 'Unique identifier for the job. Modify this field at your convenience.';
    ttopts     = 'NSG options for the job to be submitted. See >> pop_nsg help';
    ttrun      = 'Submit the job to run on NSG';
    
    % GUI components
    uilist = { { 'style' 'text'       'string' 'Select job' 'fontweight' 'bold' 'TooltipString' ttjobs} ...                                  % Label Select job
               { 'style' 'pushbutton' 'string' 'Refresh job list' 'callback' cbrescan 'TooltipString' ttrefresh }...                         % Button rescan
               { 'style' 'Checkbox'   'string' 'Auto-refresh job list' 'callback' cbarescan 'TooltipString' ttarefresh 'Tag', 'arefresh'}... % Button autorescan
               { 'style' 'pushbutton' 'string' 'Delete this NSG job' 'callback' cdelete 'TooltipString' ttdelete} ...                        % Button delete
               { 'style' 'listbox'    'string' jobnames 'tag' 'joblist' 'callback' cblist 'TooltipString' ttjobs}...                         % List jobs
               { 'style' 'pushbutton' 'string' 'MATLAB output log' 'tag' 'outputlog' 'callback' cbstdout 'TooltipString' ttoutlog} ...       % Button output log
               { 'style' 'pushbutton' 'string' 'MATLAB error log' 'tag' 'errorlog' 'callback' cbstderr 'TooltipString' tterrlog} ...         % Button error log
               { 'style' 'pushbutton' 'string' 'Download job results' 'tag' 'download' 'callback' cboutput 'TooltipString' ttresults}...     % Button download log
               { 'style' 'pushbutton' 'string' 'Load/plot results' 'tag' 'loadplot' 'callback' cbloadplot 'TooltipString' ttload}...         % Button plot
               { 'style' 'text'       'string'  'Job color legend:'          'Tag' 'legend0'} ...                                            % legend 0
               { 'style' 'text'       'string'  [char(8226) ' Completed']    'Tag' 'legend1'} ...                                            % legend 1    
               { 'style' 'text'       'string'  [char(8226) ' Processing']   'Tag' 'legend2'} ...                                            % legend 2
               { 'style' 'text'       'string'  [char(8226) ' MATLAB Error'] 'Tag' 'legend3'} ...                                            % legend 3
               { 'style' 'text'       'string'  [char(8226) ' NSG Error']    'Tag' 'legend4'} ...                                            % legend 4
               { 'style' 'text'       'string' 'NSG job status' 'fontweight' 'bold' }...                                                     % Label Status
               { 'style' 'text'       'string' ' ' 'tag' 'jobstatus'}...                                                                     % Text job Status
               { 'style' 'text'       'string' joblog 'tag' 'joblog' }...                                                                    % List Joblog
               { 'style' 'text'       'string' 'Submit new NSG job' 'fontweight' 'bold' } ...                                                % Label submit
               { 'style' 'text'       'string' 'Job folder or .zip file' 'TooltipString' ttfile} ...                                         % Label select file 
               { 'style' 'edit'       'string' '' 'tag' 'fileorfolder' 'TooltipString' ttfile} ...                                           % Edit Filepath
               { 'style' 'pushbutton' 'string' 'Browse...'    'callback' cbload 'TooltipString' ttbrowse}...                                 % Button load file
               { 'style' 'text'       'string' 'Matlab script to execute' 'TooltipString' ttmatfile}...                                      % Label File to execute
               {'style'  'popupmenu'  'string' g.filename 'tag' 'listbox_mfile' 'callback' cbmfileset 'TooltipString' ttmatfile}...          % Popup menu file to execute
               {'style'  'pushbutton' 'string' 'Test job locally' 'callback' cbtest 'TooltipString' tttest}...                               % Button test
               {'style'  'text'       'string' 'Job ID (default or custom)' 'TooltipString' ttjobid}...                                      % Label Job ID
               {'style'  'edit'       'string' ' ' 'tag' 'edit_jobid' 'TooltipString' ttopts}...                                             % Edit  Job ID
               {'style'  'text'       'string' 'NSG run options (see Help)' 'TooltipString' ttopts}...                                       % Label Run options
               {'style'  'edit'       'string' ' ' 'tag' 'edit_runopt'}...                                                                   % Edit run options                        
               {'style'  'pushbutton' 'string' 'Help', 'tag' 'help' 'callback', 'pophelp(''pop_nsg'')' }...                                  % Button Help
               {'style'  'pushbutton' 'string' 'Close', 'tag' 'cc' 'callback' cbcancel} ...                                                  % Button Cancel
               {'style'  'pushbutton' 'string' 'Run job on NSG' 'tag' 'runnsg' 'callback' cbrun  'TooltipString', ttrun} };                  % Button Run job                 
    
    ht = 20.6; wt = 7.5;
    horzspan  = 1.8; vertspam = 1.2; c1 = 0.9; c2 = 2.55; c3 = 5.2; c4 = 6.8;    
    geom = { {wt ht [c2 0]        [1 vertspam]   } ...        % Label Select job
             {wt ht [c1 1]        [horzspan vertspam] } ...   % Button rescan
             {wt ht [c1 2.33]     [horzspan vertspam] } ...   % Button autorescan
             {wt ht [c1 5]        [horzspan vertspam] }...    % Button delete
             {wt ht [c2 1]        [4.4 5]   } ...             % List jobs
             {wt ht [c4 1]        [horzspan vertspam] } ...   % Button output log
             {wt ht [c4 2.33]     [horzspan vertspam] }...    % Button error log
             {wt ht [c4 3.66]     [horzspan vertspam] }...    % Button download log
             {wt ht [c4 5]        [horzspan vertspam] }...    % Button plot
             {wt ht [c2 5.6]      [horzspan vertspam] }...    % Legend 0
             {wt ht [c2+1 5.6]    [horzspan vertspam] }...    % Legend 1
             {wt ht [c2+1.75 5.6] [horzspan vertspam] }...    % Legend 2
             {wt ht [c2+2.55 5.6] [horzspan vertspam] }...    % Legend 3
             {wt ht [c2+3.5 5.6]  [horzspan-1 vertspam] }...  % Legend 4
             {wt ht [c1 6.4]      [horzspan vertspam] }...    % Label Status
             {wt ht [c2 6.4]      [horzspan vertspam] }...    % Text Job Status
             {wt ht [c2 6.6]      [5 6.5]   }...              % List Joblog
             {wt ht [c1 11.7]     [horzspan vertspam] } ...   % Label submit
             {wt ht [c1 12.7]     [horzspan vertspam] } ...   % Label select file 
             {wt ht [c2 12.7]     [4.4 vertspam] } ...        % Edit Filepath
             {wt ht [c4 12.7]     [horzspan vertspam] }...    % Button load file
             {wt ht [c1 14]       [horzspan vertspam] } ...   % Label File to execute
             {wt ht [c2 14]       [3 vertspam] } ...          % Popup menu file to execute
             {wt ht [c4 14]       [horzspan vertspam] }...    % Button test
             {wt ht [c1 15.3]     [horzspan vertspam] } ...   % Label Job ID
             {wt ht [c2 15.3]     [3 vertspam] } ...          % Edit Job ID
             {wt ht [c1 17.2]     [horzspan vertspam] } ...   % Label Run options
             {wt ht [c2 17.2]     [4.4 vertspam] } ...        % Edit run options
             {wt ht [c1 20.6]     [horzspan vertspam] } ...   % Button Help
             {wt ht [c4 20.6]     [horzspan vertspam] } ...   % Button Cancel
             {wt ht [c2 18.4]     [horzspan 1.5*vertspam] }}; % Button Run job
         
    for i = 1:length(geom), geom{i}{3} = geom{i}{3}-1; end 
    
    % GUI setup
    set(fig, 'Visible', 'on');
    supergui('fig', fig, 'geom', geom, 'uilist', uilist, 'userdata', '', 'title' , 'NSG-R Matlab/EEGLAB interface -- pop_nsg()');
    figpos = get(fig, 'Position');
    set(fig, 'Units', 'Normalized', 'Position',[figpos(1) figpos(2) 0.46 figpos(4)],'visible', 'on');
    
    % Color of text
    set(findobj('Tag', 'legend1'), 'ForegroundColor',  [0.1328    0.5430    0.1328]);
    set(findobj('Tag', 'legend2'), 'ForegroundColor',  [0.1172    0.5625    1.0000]);
    set(findobj('Tag', 'legend3'), 'ForegroundColor',  [0.6953    0.1328    0.1328]);
    set(findobj('Tag', 'legend4'), 'ForegroundColor',  [1.0000    0.2695         0]);
    pop_nsg(fig, 'update');
      
else
    % GUI calls
    if ishandle(fig)
        newjob  = get(findobj(fig, 'tag', 'fileorfolder'), 'string');
        joblist = get(findobj(fig, 'tag', 'joblist'), 'string');
        tmplist = get(findobj(fig, 'tag', 'listbox_mfile'), 'string');
        if isempty(g.listvalue), g.listvalue = get(findobj(fig, 'tag', 'joblist'), 'value'); end
        
        % Def .m file to run
        if any(strcmp(str,{'rungui', 'test'}))
            % mfiles
            if ~isempty(deblank(tmplist))
                g.filename = tmplist{get(findobj(fig, 'tag', 'listbox_mfile'), 'value')}; % Updating mfile
                g.jobid    = get(findobj(fig, 'tag', 'edit_jobid'), 'string');
            else
                warndlg2('Select MATLAB script to execute'); return;
            end            
        end
        
        jobstr = '';
        if ~isempty(joblist)
            jobstruct = get(fig, 'userdata');
            joblist =  {jobstruct.url};
            if ~strcmp(str,'rescan'),jobstr = joblist{g.listvalue}; end          
        end
                
    % Command line calls    
    else
        if isstruct(str) 
            if isfield(str,'selfUri')
                valargin = str.selfUri.url;
            else
                error('pop_nsg: Invalid job structure provided as input');
            end
        else
            valargin = str;
        end
        str = fig; % Here fig is the input.   
    end
    
    switch str
        case 'loadplot'
               nsg_info;
               resjob  = nsg_jobs([ jobstr '/output' ]);
               flagerror = 0;
               if ~isempty(resjob.results.jobfiles)
                   zipfilepos = find(cell2mat(cellfun(@(x) strcmpi(x.parameterName,'outputfile'),resjob.results.jobfiles.jobfile,'UniformOutput',0)));
                   if ~isempty(zipfilepos)
                       [tmp, tmpval] = fileparts(resjob.results.jobfiles.jobfile{zipfilepos}.filename);
                       [tmp, foldname] = fileparts(tmpval);
                       tmpFolder = fullfile(outputfolder, foldname);
                       if exist(tmpFolder,'dir')
                           nsg_uilistfiles(tmpFolder,'oklabel', 'Load/plot' );
                       else
                           disp('pop_nsg: Unable to load/plot results. Results must be downloaded first');
                           return;
                       end
                   else
                       flagerror = 1;
                   end
               else
                   flagerror = 1;
               end
               
               if flagerror
                   disp([10 'pop_nsg: Unable to load/plot results. Either the computation has' 10 'not finished or something else went wrong while retreiving results']);
                   return;
               end
               
        case 'autorescan'
            if get(findobj('Tag', 'arefresh'), 'Value')
                t = timer;
                t.Period =  30;
                t.ExecutionMode = 'fixedRate';
                t.TasksToExecute = 10000;
                t.BusyMode = 'queue';
                t.Tag = 'nsg_autorescantimer';
                t.TimerFcn = @(~,~)pop_nsg(findobj('tag', 'pop_nsg'),'rescan');
                start(t);
            else
                stop_autorescan;
            end
            
        case 'rescan'
            res = nsg_jobs;
            jobstruct = backupjobstatus(res);
            set(findobj(fig, 'tag', 'joblist'), 'value', g.listvalue, 'string', {jobstruct.dispname});
            pop_nsg(fig, 'update');
            
        case 'deletegui'   
            if ~isempty(jobstr)
                pop_nsg('delete', jobstr);
            end
            pop_nsg(fig, 'rescan','listvalue',1);
            
        case 'delete'
            if ~isempty(valargin)
                % Command line output
                tmpcurrentjob = nsg_jobs(valargin);
                currentjob = tmpcurrentjob.jobstatus;
                currentjob.jobStage = 'DELETED';
                % Deleting job
                nsg_delete(valargin);         
            end
    
        case 'update'
            joblog   = char(ones(7,70)*' ');
            set(findobj(fig, 'tag', 'jobstatus'), 'string', ' ');
            set(findobj(fig, 'tag', 'joblog'), 'string', joblog);
            drawnow;
            
            % Disabling buttons
            set(findobj(fig, 'tag', 'outputlog'), 'enable', 'off');
            set(findobj(fig, 'tag', 'errorlog'), 'enable', 'off');
            set(findobj(fig, 'tag', 'download'), 'enable', 'off');
            set(findobj(fig, 'tag', 'loadplot'), 'enable', 'off');
            
            if ~isempty(jobstr)
                if ~isempty(jobstruct(g.listvalue))
                    % Enabling buttons
                    jobstage = jobstruct(g.listvalue).jobstage;                   
                    set(findobj(fig, 'tag', 'jobstatus'), 'string', jobstage);
                    set(findobj(fig, 'tag', 'outputlog'), 'enable', 'on');        
                    if strcmpi(jobstage, 'completed')
                        set(findobj(fig, 'tag', 'errorlog'), 'enable', 'on');
                        set(findobj(fig, 'tag', 'download'), 'enable', 'on');
                        set(findobj(fig, 'tag', 'loadplot'), 'enable', 'on');
                    end
                    set(findobj(fig, 'tag', 'joblog'), 'string', jobstruct(g.listvalue).jobtxt);
                end
            end
            
            % Auto-refresh stuff
            if get(findobj('Tag', 'arefresh'), 'Value') && all(cellfun(@(x) strcmpi(x,'completed'), {jobstruct.jobstage})) || all(cellfun(@(x) isempty(x), {jobstruct.jobstage}))
                stop_autorescan;
            end

        case 'stdout'
            if isempty(jobstr),disp('pop_nsg: No jobs were found.');return;end
            url = '';
            if strcmpi( jobstruct(g.listvalue).jobstage,'completed')
                resjob  = nsg_jobs([ jobstr '/output' ]);
                if ~isempty(resjob.results.jobfiles)
                    url = geturl(resjob.results.jobfiles.jobfile, 'STDOUT');
                end
            else
                allfiles  = nsg_jobs([ jobstr '/workingdir' ]);
                if ~isempty(allfiles) && isfield(allfiles,'workingdir') && ~isempty(allfiles.workingdir.jobfiles)
                    hittmp  = find(cellfun(@(x) strcmpi(x.filename,'stdout.txt'),allfiles.workingdir.jobfiles.jobfile));
                    if ~isempty(hittmp)
                        url = [ jobstr '/workingdir/stdout.txt'];
                    end
                end
            end
            if ~isempty(url)
                resfile = nsg_jobs(url, 'txt');
            else
                resfile = pwd; % any folder
            end
            tmp = dir(resfile);
            if tmp(1).bytes == 0 || isempty(url)
                warndlg2(['File is empty, check for errors' char(10) 'If you were checking for intermediate output log, try again later.']);
            else
                pophelp(resfile, 1);
            end
            
        case 'stderr'
            if isempty(jobstr),disp('pop_nsg: No jobs were found.');return;end
            resjob  = nsg_jobs([ jobstr '/output' ]);
            if ~isempty(resjob.results.jobfiles)
                url = geturl(resjob.results.jobfiles.jobfile, 'STDERR');
            else
                url = '';
            end
            if ~isempty(url)
                resfile = nsg_jobs(url, 'txt');
            else
                resfile = pwd; % any folder
            end
            tmp = dir(resfile);
            if tmp(1).bytes == 0 || isempty(url)
                warndlg2('File is empty, check text output');
            else
                pophelp(resfile, 1);
            end
            
        case 'outputgui' 
            if isempty(jobstr),disp('pop_nsg: No jobs were found.');return;end
            pop_nsg('output', jobstr);

        case 'output'
            if isempty(valargin),disp('pop_nsg: No jobs were found.');return;end
            resjob  = nsg_jobs([ valargin '/output' ]);
            restmp = 0;
            if ~isempty(resjob.results.jobfiles)
                % Find zip file of results (name is not fixed anymore)
                zipfilepos = find(cell2mat(cellfun(@(x) strcmpi(x.parameterName,'outputfile'),resjob.results.jobfiles.jobfile,'UniformOutput',0)));
                if ~isempty(zipfilepos)
                    % Getting name of results file
                    [tmp, tmpval] = fileparts(resjob.results.jobfiles.jobfile{zipfilepos}.filename);
                    [tmp, foldname] = fileparts(tmpval);
                    % Pulling results
                    restmp  = nsg_jobs(resjob.results.jobfiles.jobfile{zipfilepos}.downloadUri.url, 'zip',foldname);
                end
            end
            if restmp == 0
                warndlg2('File is empty, check error');
            else
                disp([ 'File downloaded and decompressed in the' 10 'output folder specified in the settings']);
            end          
            % Command line output
            tmpcurrentjob = nsg_jobs(valargin);
            currentjob = tmpcurrentjob.jobstatus;
            
        case 'testgui'
            if isempty(newjob)
                warndlg2('Empty input');
            else
                pop_nsg('test',newjob);
            end
            
        case 'test'
            if isempty(valargin)
                warndlg2('Empty input');
            else
                nsg_test(valargin);
            end
            
        case 'rungui' 
             if isempty(newjob)
                warndlg2('Empty input');
             else  
                 % Retreive parameters
                tmpoptparams   = eval( [ '{' get(findobj(gcf,'tag','edit_runopt'),'string') '}' ] );
                tmpparams_name = tmpoptparams(1:2:end);
                
                % Update parameters here
                c =1;
                for i = 1: length(tmpparams_name)
                    g.(tmpparams_name{i}) =  tmpoptparams{c+1};
                    c = c+2;
                end
                
                nsgrunoptname  = {'jobid' 'outfile' 'runtime' 'filename' 'subdirname'};
                c = 1;
                for i = 1:length(nsgrunoptname)
                    tmpparams{c} = nsgrunoptname{i};
                    tmpparams{c+1} = g.(nsgrunoptname{i});
                    c = c+2;
                end
                
                pop_nsg('run', newjob, tmpparams{:});
                tmpjoblist = get(findobj(gcf,'tag','joblist'),'string');
                if length(tmpjoblist)>1 
                    listpos = length(tmpjoblist)+1;
                elseif length(tmpjoblist)==1 && ~isempty(tmpjoblist{1})
                    listpos = 2;
                else
                    listpos = 1;
                end               
                pop_nsg(fig, 'rescan','listvalue',listpos);
             end    
             
        case 'run'
            if isempty(valargin)
                warndlg2('Empty input');
            else  
                if isempty(g.jobid)
                    g.jobid = [filenamenoext num2str(ceil(1000*rand(1)))];
                end
                if isempty(g.outfile)
                    g.outfile = ['nsgresults_' g.jobid];
                end
                currentjoburl = nsg_run(valargin,'jobid', g.jobid,'outfile',g.outfile,'runtime',g.runtime,'filename', g.filename, 'subdirname', g.subdirname);                
                % Command line output
                if ~isempty(currentjoburl)
                    tmpcurrentjob = nsg_jobs(currentjoburl);
                    currentjob = tmpcurrentjob.jobstatus;
                end
            end
    end 
    
    % Command line output
    if ~ishandle(fig)
        tmpalljobs    = nsg_jobs;
        if ~isempty(tmpalljobs.joblist.jobs)
            alljobs = tmpalljobs.joblist.jobs.jobstatus;
        end
    end
end
end
% ---
function url = geturl(results, resultType)
url = '';
if ~iscell(results)
    results = {};
end

for iRes = 1:length(results)
    if strcmpi(results{iRes}.downloadUri.title, resultType)
        url = results{iRes}.downloadUri.url;
    end
end
end

% ---   
function urlflag = isnsgurl(urlcheck)
if length(urlcheck)>= 21
    urlflag =fastif(strcmp('https://nsgr.sdsc.edu',urlcheck(1:21)),1,0);  
else
    urlflag = 0;
end
end

% --- 
function jobstruct = backupjobstatus(res)
guihandle = findobj('Tag', 'pop_nsg');
jobstruct = struct('url', '','jopbid', '','jobtxt','','jobstage','','nsgerrorflag','','matlaberrorflag','','dispname','');

% Get URL
if isfield(res,'joblist')
    if ~isempty(res.joblist.jobs)
        jobStatus = res.joblist.jobs.jobstatus;
    else
        jobStatus = [];
    end
else %isfield(res,'jobstatus')
    jobStatus = res.jobstatus;
end

if ~isempty(jobStatus)
    if ~iscell(jobStatus), jobStatus = { jobStatus }; end
    for iJob = 1:length(jobStatus)
        jobstruct(iJob).url = jobStatus{iJob}.selfUri.url;
    end
    
    % Get job id
    jobnames = nsg_getjobid({jobstruct.url},1,res);
    
    % ---- AFTER HERE WE SHOULD WORK ONLY WITH 'jobstatus' instead of 'res'
    for i = 1:length(jobnames)
        jobstruct(i).jobid = jobnames{i};
        if iscell(jobStatus{i}.messages.message)
            stage = jobStatus{i}.messages.message{end}.stage;
            jobtxt = cellfun(@(x)x.text, jobStatus{i}.messages.message, 'uniformoutput', false);
        else
            stage = jobStatus{i}.messages.message.stage;
            jobtxt = { jobStatus{i}.messages.message.text };
        end
        failflag = jobStatus{i}.failed;
        
        for iLine = 1:length(jobtxt)
            if length(jobtxt{iLine}) > 70
                jobtxt{iLine} = [ jobtxt{iLine}(1:67) '...' ];
            end
        end
        
        jobstruct(i).jobtxt = strvcat(jobtxt{:});
        jobstruct(i).jobstage = stage;
        jobstruct(i).nsgerrorflag = failflag;
        
        % Reading MATLAB log if COMPLETED
        jobstruct(i).matlaberrorflag = [];
        if strcmpi(stage, 'completed')
            resjob  = nsg_jobs([jobstruct(i).url '/output']);
            if ~isempty(resjob.results.jobfiles)
                url = geturl(resjob.results.jobfiles.jobfile, 'STDOUT');
            else
                url = '';
            end
            if ~isempty(url)
                resfile = nsg_jobs(url, 'txt');
            else
                resfile = pwd; % any folder
            end
            tmp = dir(resfile);
            fid = fopen(fullfile(tmp.folder,'tmptxt.txt'));
            matlog = textscan(fid,'%q');
            jobstruct(i).matlaberrorflag = ~isempty(find(cell2mat(cellfun(@(x)strcmp(x,'Error'), matlog{1}, 'UniformOutput', 0))));
        end
        
        % Job  status
        if strcmpi(stage, 'completed') %
            if jobstruct(i).matlaberrorflag
                jobnameout = ['<html><font size=+0 color="#e600000"> ' jobnames{i} '</html>']; % MATLAB error
            else
                jobnameout = ['<html><font size=+0 color="#00cc00"> ' jobnames{i} '</html>']; % Completed
            end
        elseif strcmp(failflag, 'true')
            jobnameout = ['<html><font size=+0 color="#4d94ff"> ' jobnames{i} '</html>']; % NSG error
        else
            jobnameout =['<html><font size=+0 color="#4d94ff"> ' jobnames{i} '</html>']; % Proccesing
        end
        jobstruct(i).dispname = jobnameout;
    end
end

% Store in figure
set(guihandle,'userdata', jobstruct); 
end

% ---
function stop_autorescan
timerobjtmp = timerfindall('Tag','nsg_autorescantimer');
figobjttmp = findobj('Tag', 'arefresh');
if ~isempty(timerobjtmp)
    stop(timerobjtmp);
    delete(timerobjtmp);
end
if ~isempty(figobjttmp)
    set(figobjttmp, 'Value',0);
end
end