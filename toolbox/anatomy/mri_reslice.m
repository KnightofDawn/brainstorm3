function [MriFileReg, errMsg, fileTag, sMriReg] = mri_reslice(MriFileSrc, MriFileRef, TransfSrc, TransfRef)
% MRI_RESLICE: Use the MNI transformation to .
%
% USAGE:  [MriFileReg, errMsg, fileTag] = mri_reslice(MriFileSrc, MriFileRef, TransfSrc, TransfRef)
%            [sMriReg, errMsg, fileTag] = mri_reslice(sMriSrc,    sMriRef, ...)
%
% INPUTS:
%    - MriFileSrc : Relative path to the Brainstorm MRI file to register
%    - MriFileRef : Relative path to the Brainstorm MRI file used as a reference
%    - sMriSrc    : Brainstorm MRI structure to register (fields Cube, Voxsize, SCS, NCS...)
%    - sMriRef    : Brainstorm MRI structure used as a reference
%    - TransfSrc  : Transformation for the MRI to register, or 'ncs'/'scs'/'vox2ras'
%    - TransfRef  : Transformation for the reference MRI, or 'ncs'/'scs'/'vox2ras'
%
% OUTPUTS:
%    - MriFileReg : Relative path to the new Brainstorm MRI file (containing the structure sMriReg)
%    - sMriReg    : Brainstorm MRI structure with the registered volume
%    - errMsg     : Error messages if any
%    - fileTag    : Tag added to the comment/filename

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, 2016-2017

% ===== PARSE INPUTS =====
sMriReg = [];
errMsg = [];
% Progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'MRI register', 'Loading input volumes...');
end
% USAGE: mri_reslice(sMriSrc, sMriRef)
if isstruct(MriFileSrc)
    sMriSrc = MriFileSrc;
    sMriRef = MriFileRef;
    MriFileSrc = [];
    MriFileRef = [];
% USAGE: mri_reslice(MriFileSrc, MriFileRef)
elseif ischar(MriFileSrc)
    % Get the default MRI for this subject
    if isempty(MriFileRef)
        sSubject = bst_get('MriFile', MriFileSrc);
        MriFileRef = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    end
    % Load MRI volumes
    sMriSrc = in_mri_bst(MriFileSrc);
    sMriRef = in_mri_bst(MriFileRef);
else
    error('Invalid call.');
end


% ===== GET NCS/SCS TRANSFORMATIONS =====
fileTag = '';
% Source MRI
if ischar(TransfSrc)
    if strcmpi(TransfSrc, 'ncs')
        if ~isfield(sMriSrc, 'NCS') || ~isfield(sMriSrc.NCS, 'R') || ~isfield(sMriSrc.NCS, 'T') || isempty(sMriSrc.NCS.R) || isempty(sMriSrc.NCS.T)
            [sMriSrc,errMsg] = bst_normalize_mni(sMriSrc);
        end
        if isempty(errMsg)
            TransfSrc = [sMriSrc.NCS.R, sMriSrc.NCS.T; 0 0 0 1];
        end
        fileTag = '_mni';
    elseif strcmpi(TransfSrc, 'scs')
        if ~isfield(sMriSrc, 'SCS') || ~isfield(sMriSrc.SCS, 'R') || ~isfield(sMriSrc.SCS, 'T') || isempty(sMriSrc.SCS.R) || isempty(sMriSrc.SCS.T)
            errMsg = 'No SCS transformation available for the input volume. Set the fiducials first.';
        else
            TransfSrc = [sMriSrc.SCS.R, sMriSrc.SCS.T; 0 0 0 1];
        end
        fileTag = '_scs';
    elseif strcmpi(TransfSrc, 'vox2ras')
        if ~isfield(sMriSrc, 'InitTransf') || isempty(sMriSrc.InitTransf) || ~any(ismember(sMriSrc.InitTransf(:,1), 'vox2ras'))
            errMsg = 'No vox2ras transformation available for the input volume.';
        else
            iTransfSrc = find(strcmpi(sMriSrc.InitTransf(:,1), 'vox2ras'));
            TransfSrc = sMriSrc.InitTransf{iTransfSrc(1),2};
            % 2nd operation: Change reference from (0,0,0) to (.5,.5,.5)
            TransfSrc = TransfSrc * [1 0 0 -.5; 0 1 0 -.5; 0 0 1 -.5; 0 0 0 1];
            % 1st operation: Convert from MRI(mm) to voxels
            TransfSrc = TransfSrc * diag(1 ./ [sMriSrc.Voxsize, 1]);
        end
        fileTag = '';
    end
end
% Reference MRI
if ischar(TransfRef)
    if strcmpi(TransfRef, 'ncs')
        if ~isfield(sMriRef, 'NCS') || ~isfield(sMriRef.NCS, 'R') || ~isfield(sMriRef.NCS, 'T') || isempty(sMriRef.NCS.R) || isempty(sMriRef.NCS.T)
            [sMriRef,errMsg] = bst_normalize_mni(sMriRef);
        end
        if isempty(errMsg)
            TransfRef = [sMriRef.NCS.R, sMriRef.NCS.T; 0 0 0 1];
        end
    elseif strcmpi(TransfRef, 'scs')
        if ~isfield(sMriRef, 'SCS') || ~isfield(sMriRef.SCS, 'R') || ~isfield(sMriRef.SCS, 'T') || isempty(sMriRef.SCS.R) || isempty(sMriRef.SCS.T)
            errMsg = 'No SCS transformation available for the reference volume. Set the fiducials first.';
        else
            TransfRef = [sMriRef.SCS.R, sMriRef.SCS.T; 0 0 0 1];
        end
    elseif strcmpi(TransfRef, 'vox2ras')
        if ~isfield(sMriRef, 'InitTransf') || isempty(sMriRef.InitTransf) || ~any(ismember(sMriRef.InitTransf(:,1), 'vox2ras'))
            errMsg = 'No vox2ras transformation available for the reference volume.';
        else
            iTransfRef = find(strcmpi(sMriRef.InitTransf(:,1), 'vox2ras'));
            TransfRef = sMriRef.InitTransf{iTransfRef(1),2};
            % 2nd operation: Change reference from (0,0,0) to (.5,.5,.5)
            TransfRef = TransfRef * [1 0 0 -.5; 0 1 0 -.5; 0 0 1 -.5; 0 0 0 1];
            % 1st operation: Convert from MRI(mm) to voxels
            TransfRef = TransfRef * diag(1 ./ [sMriRef.Voxsize, 1]);
        end
    end
end
% Handle errors
if ~isempty(errMsg)
    if ~isempty(MriFileSrc)
        bst_error(errMsg, 'MRI reslice', 0);
    end
    return;
end


% ===== INTERPOLATE MRI VOLUME =====
% Original position vectors
X1 = ((0:size(sMriSrc.Cube,1)-1) + 0.5) .* sMriSrc.Voxsize(1);
Y1 = ((0:size(sMriSrc.Cube,2)-1) + 0.5) .* sMriSrc.Voxsize(2);
Z1 = ((0:size(sMriSrc.Cube,3)-1) + 0.5) .* sMriSrc.Voxsize(3);
% Reference position vectors
X2 = ((0:size(sMriRef.Cube,1)-1) + 0.5) .* sMriRef.Voxsize(1);
Y2 = ((0:size(sMriRef.Cube,2)-1) + 0.5) .* sMriRef.Voxsize(2);
Z2 = ((0:size(sMriRef.Cube,3)-1) + 0.5) .* sMriRef.Voxsize(3);
% Mesh grids
[Xgrid2, Ygrid2, Zgrid2] = meshgrid(Y2, X2, Z2);
% Apply final transformation: reference MRI => common space => original MRI
allGrid = [Ygrid2(:)'; Xgrid2(:)'; Zgrid2(:)'; ones(size(Xgrid2(:)))'];
allGrid = inv(TransfSrc) * TransfRef * allGrid;
Xgrid2 = reshape(allGrid(2,:), size(Xgrid2));
Ygrid2 = reshape(allGrid(1,:), size(Ygrid2));
Zgrid2 = reshape(allGrid(3,:), size(Zgrid2));

% OPTION #1: Spline interp, too memory intensive
% newCube = uint8(interp3(Y1, X1, Z1, double(sMriSrc.Cube), Xgrid2, Ygrid2, Zgrid2, 'spline', 0));

% OPTION #2: Cubic interp, very similar results, much faster
newCube = uint8(interp3(Y1, X1, Z1, double(sMriSrc.Cube), Xgrid2, Ygrid2, Zgrid2, 'cubic', 0));

%     % OPTION #3: Spline interp by block, too slow, but ok for memory usage
%     if any(size(sMriSrc.Cube) > 256)
%         nBlocks = 5;
%     else
%         nBlocks = 3;
%     end
%     nTol = 5;
%     bst_progress('start', 'MRI register', 'Reslicing volume...', 0, nBlocks^3+1);
%     % Interpolate volume by blocks
%     sizeCube = size(Xgrid2);
%     xBlockSize = ceil(sizeCube(1) / nBlocks);
%     yBlockSize = ceil(sizeCube(2) / nBlocks);
%     zBlockSize = ceil(sizeCube(3) / nBlocks);
%     % Inialize output cube
%     newCube = zeros(sizeCube, 'uint8');
%     bst_progress('inc', 1);
%     % Loop on X axis
%     for i = 1:nBlocks
%         iX2 = (((i-1)*xBlockSize)+1) : min(i*xBlockSize, sizeCube(1));
%         for j = 1:nBlocks
%             iY2 = (((j-1)*yBlockSize)+1) : min(j*yBlockSize, sizeCube(2));
%             for k = 1:nBlocks
%                 iZ2 = (((k-1)*zBlockSize)+1) : min(k*zBlockSize, sizeCube(3));
%                 % Get indices of the original cube to consider
%                 iX1 = bst_closest(min(reshape(Ygrid2(iX2,iY2,iZ2),1,[])) - nTol, X1) : ...
%                       bst_closest(max(reshape(Ygrid2(iX2,iY2,iZ2),1,[])) + nTol, X1);
%                 iY1 = bst_closest(min(reshape(Xgrid2(iX2,iY2,iZ2),1,[])) - nTol, Y1) : ...
%                       bst_closest(max(reshape(Xgrid2(iX2,iY2,iZ2),1,[])) + nTol, Y1);
%                 iZ1 = bst_closest(min(reshape(Zgrid2(iX2,iY2,iZ2),1,[])) - nTol, Z1) : ...
%                       bst_closest(max(reshape(Zgrid2(iX2,iY2,iZ2),1,[])) + nTol, Z1);
%                 % Interpolate block
%                 if (length(iX1) > 1) && (length(iY1) > 1) && (length(iZ1) > 1)
%                     newCube(iX2, iY2, iZ2) = uint8(interp3(...
%                         Y1(iY1), X1(iX1), Z1(iZ1), ...            % Indices of the reference cube
%                         double(sMriSrc.Cube(iX1, iY1, iZ1)), ...  % Values of the reference cube
%                         Xgrid2(iX2, iY2, iZ2), ...                % Coordinates for which we want to estimate the values
%                         Ygrid2(iX2, iY2, iZ2), ...
%                         Zgrid2(iX2, iY2, iZ2), 'spline', 0));
%                 end
%                 bst_progress('inc', 1);
%             end
%         end
%     end


% ===== TRANSFORM COORDINATES =====
% Initialize transformed structure
sMriReg         = sMriSrc;
sMriReg.Cube    = newCube;
sMriReg.Voxsize = sMriRef.Voxsize;
% Use the reference SCS/NCS coordinates
if isfield(sMriRef, 'SCS')
    sMriReg.SCS = sMriRef.SCS;
end
if isfield(sMriSrc, 'NCS')
    sMriReg.NCS = sMriRef.NCS;
end
if isfield(sMriRef, 'InitTransf') && ~isempty(sMriRef.InitTransf) && ismember(sMriRef.InitTransf(:,1), 'vox2ras')
    sMriReg.InitTransf = sMriRef.InitTransf;
end
if isfield(sMriRef, 'Header') && isfield(sMriRef.Header, 'nifti') && isfield(sMriRef.Header.nifti, 'vox2ras') && ~isempty(sMriRef.Header.nifti.vox2ras)
    sMriReg.Header = sMriRef.Header;
end
% % Apply transformation: reference MRI => SPM/MNI => original MRI
% Transf = inv(TransfSrc) * TransfRef;
% % Update the vox2mri transformation
% if isfield(sMriReg, 'InitTransf') && ~isempty(sMriReg.InitTransf) && ismember(sMriReg.InitTransf(:,1), 'vox2ras')
%     iTransf = find(strcmpi(sMriReg.InitTransf(:,1), 'vox2ras'));
%     sMriReg.InitTransf{iTransf,2} = sMriReg.InitTransf{iTransf,2} * Transf;
% end
% if isfield(sMriReg, 'Header') && isfield(sMriReg.Header, 'nifti') && isfield(sMriReg.Header.nifti, 'vox2ras') && ~isempty(sMriReg.Header.nifti.vox2ras)
%     sMriReg.Header.nifti.vox2ras = sMriReg.Header.nifti.vox2ras * Transf;
%     % Set sform to NIFTI_XFORM_ALIGNED_ANAT 
%     sMriReg.Header.nifti.sform_code = 2;
%     sMriReg.Header.nifti.srow_x     = sMriReg.Header.nifti.vox2ras(1,:);
%     sMriReg.Header.nifti.srow_y     = sMriReg.Header.nifti.vox2ras(2,:);
%     sMriReg.Header.nifti.srow_z     = sMriReg.Header.nifti.vox2ras(3,:);
% end


% ===== SAVE NEW FILE =====
% Add file tag
fileTag = [fileTag, '_reslice'];
sMriReg.Comment = [sMriSrc.Comment, fileTag];
% Save output
if ~isempty(MriFileSrc)
    bst_progress('text', 'Saving new file...');
    % Get subject
    [sSubject, iSubject, iMri] = bst_get('MriFile', MriFileSrc);
    % Update comment
    sMriReg.Comment = file_unique(sMriReg.Comment, {sSubject.Anatomy.Comment});
    % Add history entry
    sMriReg = bst_history('add', sMriReg, 'resample', ['MRI co-registered on default file: ' MriFileRef]);
    % Save new file
    MriFileRegFull = file_unique(strrep(file_fullpath(MriFileSrc), '.mat', [fileTag '.mat']));
    MriFileReg = file_short(MriFileRegFull);
    % Save new MRI in Brainstorm format
    sMriReg = out_mri_bst(sMriReg, MriFileRegFull);

    % Register new MRI
    iAnatomy = length(sSubject.Anatomy) + 1;
    sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
    sSubject.Anatomy(iAnatomy).FileName = MriFileReg;
    sSubject.Anatomy(iAnatomy).Comment  = sMriReg.Comment;
    % Update subject structure
    bst_set('Subject', iSubject, sSubject);
    % Refresh tree
    panel_protocols('UpdateNode', 'Subject', iSubject);
    panel_protocols('SelectNode', [], 'anatomy', iSubject, iAnatomy);
    % Save database
    db_save();
else
    % Return output structure
    MriFileReg = sMriReg;
end
% Close progress bar
if ~isProgress
    bst_progress('stop');
end


