% nsg_findclientjoburl() - Given a Client Job ID, find and returns job URL 
%                          and job object. In case the job is not found
%                          will return empty outputs.
%                          
% Usage: 
%             >> [jobURL, jobstruct] = nsg_findclientjoburl(clientjobid);  
%
% Inputs:
%  clientjobid  - String with the client job id. This was assigned to the
%                 job when created.
% Outputs:
%  jobURL       - [string] Job URL
%  jobstruct    - [structure] Job object structure.
%   
%  See also: nsg_delete(), nsg_jobs(), nsg_test(), nsg_run()
%
% Authors: Ramon Martinez-Cancino and Arnaud Delorme, SCCN/INC/UCSD 2019

% Copyright (C) Ramon Martinez-Cancino and Arnaud Delorme
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

function [jobURL, jobstruct] = nsg_findclientjoburl(clientjobid)

jobURL = []; jobindx = []; jobstruct= [];

alljobs = nsg_jobs;
njobs = length(alljobs.joblist.jobs.jobstatus);
if ~isempty(alljobs.joblist.jobs)
    for i =1:njobs
        if njobs ~= 1
            tmp = alljobs.joblist.jobs.jobstatus{i};
        else
            tmp = alljobs.joblist.jobs.jobstatus;
        end
            
        tmphit = find(cellfun(@(x) strcmp(x.value,clientjobid),tmp.metadata.entry));
        if ~isempty(tmphit)
            jobindx = i;
        end
    end
    if ~isempty(jobindx)
        if njobs ~= 1
            jobURL = alljobs.joblist.jobs.jobstatus{i}.selfUri.url;
            jobstruct = alljobs.joblist.jobs.jobstatus{i};
        else
            jobURL = alljobs.joblist.jobs.jobstatus.selfUri.url;
            jobstruct = alljobs.joblist.jobs.jobstatus;
        end
    end
end