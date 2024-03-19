function angle_DCgains(plotTitle, fileName, aParams, Cparams, inputsOpt, varargin)
% This function is passed parameters from a C matrix (state-to-output)
% terms and terms from a B matrix (input-to-state terms) and terms from an
% A matrix (state dynamics) to get the DC gain C((I-A)^{-1})B
% and compares the angles between input-specific terms

% Note: I didn't bother changing too many of the comments and names from the
% angle_CBproducts function, so many of the variable names and comments
% may not match up

% ---------- Inputs ---------- %
% plotTitle: Just so the plots have some meaningful title
% fileName: file name to use when saving figure
% aParams: either a cell array of A matrices, one per subject, or a single
%          A matrix for a single subject
% Cparams: either a cell array of C matrices, one per subject, or a single
%          C matrix for a single subject
% inputsOpt: string that specifies which protocol conditions
%            inputs were created for - 
%            'v': just VNS
%            'vt': VNS and trauma recall
%            'vn': VNS and neutral condition
%            'vtn': VNS, trauma recall, and neutral
% ---> the next varargin inputs needs to be the b parameters arranged into
%      columns according to inputsOpt (e.g., if inputsOpt is 'vn', then the
%      first column needs to be b_v, and the 2nd column needs to be b_n)
% (optional) 
% 'elementNums' - if the user enters this flag, the next varargin needs to
%                 be a vector of element numbers to include in the analysis
%                 (useful to compare angles in lower dimension of one's
%                  choosing)

% Parse varargin
if strcmp(inputsOpt, 'vtn')
    numInputs = 3;  % Store number of inputs
    inputs = varargin{1};
elseif strcmp(inputsOpt, 'vt') || strcmp(inputsOpt, 'vn')
    numInputs = 2;  % Store number of inputs
    inputs = varargin{1};
else
    numInputs = 1;  % Store number of inputs
    inputs = varargin{1};
end
for arg = 2:length(varargin)
    if strcmp(varargin{arg}, 'elementNums')
        elementNums = varargin{arg + 1};
    end
end

% Set defaults
if ~exist('elementNums', 'var')
    if iscell(inputs)
        % Use all elements
        elementNums = 1:size(Cparams{1}*inputs{1}, 1);
    else
        % Use all elements
        elementNums = 1:size(Cparams*inputs, 1);
    end
end

% Compute number of pairs
if numInputs == 2
    numPairs = 1;
elseif numInputs == 3
    numPairs = 3;
else
    numPairs = 0;
end

% Check if inputs is a cell array or not; if cell array, that means we need
% to create a boxplot to plot an entire group's data
if iscell(inputs)
    % Create new arrays to store all the angles and dot products
    angles_all = zeros(numel(inputs), numPairs);
    dotProds_all = zeros(numel(inputs), numPairs);
    
    % Loop through all and compute angles, if there are pairs to work with
    if ~isempty(angles_all)
        for sub = 1:numel(inputs)
            % Compute angles between normalized pairs
            p = 1;  % Pair index
            for p1 = 1:(numInputs-1)
                for p2 = (p1+1):numInputs
                    % Compute products and store away desired elements
                    vec1_full = Cparams{sub}*...
                        inv(eye(size(aParams{sub}, 1)) - ...
                        aParams{sub})*inputs{sub}(:, p1);
                    vec1_desired = vec1_full(elementNums);
                    
                    vec2_full = Cparams{sub}*...
                        inv(eye(size(aParams{sub}, 1)) - ...
                        aParams{sub})*inputs{sub}(:, p2);
                    vec2_desired = vec2_full(elementNums);
                    
                    % Make vectors unit norm
                    vec1_normed = (1/norm(vec1_desired))*vec1_desired;
                    vec2_normed = (1/norm(vec2_desired))*vec2_desired;
                    
                    % Take arc cosine of the dot product and convert to degrees
                    dotProds_all(sub, p) = vec1_normed'*vec2_normed;
                    angles_all(sub, p) = (180/pi)*acos(vec1_normed'*...
                        vec2_normed);
                    
                    p = p + 1;  % increment pair counter
                end
            end
        end
        
        % Compute p values for pairwise comparisons between groups, if applic.
        if numPairs == 2
            % Either signed rank test or paired t test
            if swtest(angles_all(:, 1)) || swtest(angles_all(:, 2))
                [pVal1, ~] = signrank(angles_all(:, 1), angles_all(:, 2));
                statsAppend = [': P_1 = ', num2str(pVal1), '(SR)'];
            else
                [~, pVal1] = ttest(angles_all(:, 1), angles_all(:, 2));
                statsAppend = [': P_1 = ', num2str(pVal1), '(TT)'];
            end
        elseif numPairs == 3
            % First p value
            if swtest(angles_all(:, 1)) || swtest(angles_all(:, 2))
                [pVal1, ~] = signrank(angles_all(:, 1), angles_all(:, 2));
                statsAppend_1 = [': P_{12} = ', num2str(pVal1), '(SR)'];
            else
                [~, pVal1] = ttest(angles_all(:, 1), angles_all(:, 2));
                statsAppend_1 = [': P_{12} = ', num2str(pVal1), '(TT)'];
            end
            % Second p value
            if swtest(angles_all(:, 3)) || swtest(angles_all(:, 2))
                [pVal2, ~] = signrank(angles_all(:, 3), angles_all(:, 2));
                statsAppend_2 = ['; P_{23} = ', num2str(pVal2), '(SR)'];
            else
                [~, pVal2] = ttest(angles_all(:, 3), angles_all(:, 2));
                statsAppend_2 = ['; P_{23} = ', num2str(pVal2), '(TT)'];
            end
            % Third p value
            if swtest(angles_all(:, 3)) || swtest(angles_all(:, 1))
                [pVal3, ~] = signrank(angles_all(:, 3), angles_all(:, 1));
                statsAppend_3 = ['; P_{31} = ', num2str(pVal3), '(SR)'];
            else
                [~, pVal3] = ttest(angles_all(:, 3), angles_all(:, 1));
                statsAppend_3 = ['; P_{31} = ', num2str(pVal3), '(TT)'];
            end
            
            statsAppend = [statsAppend_1, statsAppend_2, statsAppend_3];
        end
        
        % Create a boxplot for all norms, separated by input
        % Create one figure
        fig = figure();
        set(fig,'Visible','on')
        boxplot(angles_all);
        
        hold on
        % Scatter points and connect the ones from the same subject with lines
        x_coord = 1:numPairs;
        for sub = 1:numel(inputs)
            plot(x_coord, angles_all(sub, :), '-o')
        end
        hold off
        
        % Label x axis
        xticks(1:numPairs);
         % Label x axis
        xticks(1:numPairs);
        if numInputs == 2
            if strcmp(inputsOpt, 'vn')
                xticklabels({'\theta_{DCgain_v, DCgain_n}'});
            else
                xticklabels({'\theta_{DCgain_v, DCgain_t}'});
            end
        else
            xticklabels({'\theta_{DCgain_v, DCgain_t}', '\theta_{DCgain_v, DCgain_n}', ...
                '\theta_{DCgain_t, DCgain_n}'});
        end
        
        % Label y axis
        ylabel('Angle (degrees)')
        
        % Overall title, save, and close
        if numPairs > 1
            title([plotTitle, statsAppend])
        else
            title(plotTitle);
        end
        
        % Save
        savefig(fig, fileName);
        close all;
        
        
        % -------------- replicate code for dot products -------------- %
        % Compute p values for pairwise comparisons between groups, if applic.
        if numPairs == 2
            % Either signed rank test or paired t test
            if swtest(dotProds_all(:, 1)) || swtest(dotProds_all(:, 2))
                [pVal1, ~] = signrank(dotProds_all(:, 1), dotProds_all(:, 2));
                statsAppend = [': P_1 = ', num2str(pVal1), '(SR)'];
            else
                [~, pVal1] = ttest(dotProds_all(:, 1), dotProds_all(:, 2));
                statsAppend = [': P_1 = ', num2str(pVal1), '(TT)'];
            end
        elseif numPairs == 3
            % First p value
            if swtest(dotProds_all(:, 1)) || swtest(dotProds_all(:, 2))
                [pVal1, ~] = signrank(dotProds_all(:, 1), dotProds_all(:, 2));
                statsAppend_1 = [': P_{12} = ', num2str(pVal1), '(SR)'];
            else
                [~, pVal1] = ttest(dotProds_all(:, 1), dotProds_all(:, 2));
                statsAppend_1 = [': P_{12} = ', num2str(pVal1), '(TT)'];
            end
            % Second p value
            if swtest(dotProds_all(:, 3)) || swtest(dotProds_all(:, 2))
                [pVal2, ~] = signrank(dotProds_all(:, 3), dotProds_all(:, 2));
                statsAppend_2 = ['; P_{23} = ', num2str(pVal2), '(SR)'];
            else
                [~, pVal2] = ttest(dotProds_all(:, 3), dotProds_all(:, 2));
                statsAppend_2 = ['; P_{23} = ', num2str(pVal2), '(TT)'];
            end
            % Third p value
            if swtest(dotProds_all(:, 3)) || swtest(dotProds_all(:, 1))
                [pVal3, ~] = signrank(dotProds_all(:, 3), dotProds_all(:, 1));
                statsAppend_3 = ['; P_{31} = ', num2str(pVal3), '(SR)'];
            else
                [~, pVal3] = ttest(dotProds_all(:, 3), dotProds_all(:, 1));
                statsAppend_3 = ['; P_{31} = ', num2str(pVal3), '(TT)'];
            end
            
            statsAppend = [statsAppend_1, statsAppend_2, statsAppend_3];
        end
        
        % Create a boxplot for all norms, separated by input
        % Create one figure
        fig = figure();
        set(fig,'Visible','on')
        boxplot(dotProds_all);
        
        hold on
        % Scatter points and connect the ones from the same subject with lines
        x_coord = 1:numPairs;
        for sub = 1:numel(inputs)
            plot(x_coord, dotProds_all(sub, :), '-o')
        end
        hold off
        
        % Label x axis
        xticks(1:numPairs);
         % Label x axis
        xticks(1:numPairs);
        if numInputs == 2
            if strcmp(inputsOpt, 'vn')
                xticklabels({'DCgain_v \cdot DCgain_n'});
            else
                xticklabels({'DCgain_v \cdot DCgain_t'});
            end
        else
            xticklabels({'DCgain_v \cdot DCgain_t', 'DCgain_v \cdot DCgain_n', ...
                'DCgain_t \cdot DCgain_n'});
        end
        
        % Label y axis
        ylabel('Dot Product of Normalized Vectors')
        
        % Overall title, save, and close
        if numPairs > 1
            title([plotTitle, statsAppend])
        else
            title(plotTitle);
        end
        
        % Save
        savefig(fig, [fileName, '_dotProducts']);
        close all;
    end
else
    % Initialize vectors of angles and dot products
    angles = zeros(1, numPairs);
    dotProds = zeros(1, numPairs);
    
    % Make sure there are pairs to work with
    if ~isempty(angles)
        % Compute angles between normalized pairs
        p = 1;  % Pair index
        for p1 = 1:(numInputs-1)
            for p2 = (p1+1):numInputs
                % Compute products and store away desired elements
                vec1_full = Cparams*inv(eye(size(aParams, 1)) - aParams)*inputs(:, p1);
                vec1_desired = vec1_full(elementNums);
                
                vec2_full = Cparams*inv(eye(size(aParams, 1)) - aParams)*inputs(:, p2);
                vec2_desired = vec2_full(elementNums);
                
                % Make vectors unit norm
                vec1_normed = (1/norm(vec1_desired))*vec1_desired;
                vec2_normed = (1/norm(vec2_desired))*vec2_desired;
                
                % Take arc cosine of the dot product and convert to degrees
                dotProds(p) = vec1_normed'*vec2_normed;
                angles(p) = (180/pi)*acos(vec1_normed'*...
                    vec2_normed);
                
                p = p + 1;  % increment pair counter
            end
        end
        
        % Create a bar plot to compare these angles
        % Create one figure
        fig = figure();
        set(fig,'Visible','on')
        bar(angles);
        
        % Label x axis
        xticks(1:numPairs);
        if numInputs == 2
            if strcmp(inputsOpt, 'vn')
                xticklabels({'\theta_{DCgain_v, DCgain_n}'});
            else
                xticklabels({'\theta_{DCgain_v, DCgain_t}'});
            end
        else
            xticklabels({'\theta_{DCgain_v, DCgain_t}', '\theta_{DCgain_v, DCgain_n}', ...
                '\theta_{DCgain_t, DCgain_n}'});
        end
        
        % Label y axis
        ylabel('Angle (degrees)')
        
        % Title the plot, save, and close
        title(plotTitle);
        savefig(fig, fileName);
        close all
        
        
        % ------------ replicate code for dot products ------------ %
        % Create a bar plot to compare these angles
        % Create one figure
        fig = figure();
        set(fig,'Visible','on')
        bar(dotProds);
        
        % Label x axis
        xticks(1:numPairs);
        if numInputs == 2
            if strcmp(inputsOpt, 'vn')
                xticklabels({'DCgain_v \cdot DCgain_n'});
            else
                xticklabels({'DCgain_v \cdot DCgain_t'});
            end
        else
            xticklabels({'DCgain_v \cdot DCgain_t', 'DCgain_v \cdot DCgain_n', ...
                'DCgain_t \cdot DCgain_n'});
        end
        
        % Label y axis
        ylabel('Value of the Dot Product of Unit Vectors')
        
        % Title the plot, save, and close
        title(plotTitle);
        savefig(fig, [fileName, '_dotProducts']);
        close all
    end
end


end

