function varargout = PortExtractor(modelName, searchDepth, includeTriggerEnable, startSubsystem, useTimestamp)
% PortExtractor  提取Simulink模型的输入输出端口信息，输出到Excel文件
%
%   语法:
%       PortExtractor(modelName, searchDepth)
%       PortExtractor(modelName, searchDepth, includeTriggerEnable)
%       PortExtractor(modelName, searchDepth, includeTriggerEnable, startSubsystem)
%       PortExtractor(modelName, searchDepth, includeTriggerEnable, startSubsystem, useTimestamp)
%
%   输入参数:
%       modelName           - 模型名称（不含.slx扩展名），必须已加载
%       searchDepth         - 搜索深度（正整数，1=仅指定层）
%       includeTriggerEnable- 是否提取Trigger/Enable（可选，默认false）
%       startSubsystem      - 起始子系统路径（可选，默认''=根模型）
%       useTimestamp        - 文件名是否添加时间戳（可选，默认false）
%
%   输出:
%       ports_<modelName>.xlsx 或 ports_<modelName>_yyyymmdd_HHMMSS.xlsx
%       含 Inputs / Outputs 两个sheet
%       列：序号 | 端口名称 | 数据类型 | 指定数据类型 | StorageClass | Identifier

    %% ---------- 参数校验 ----------
    narginchk(2, 5);
    if nargin < 3, includeTriggerEnable = false; end
    if nargin < 4, startSubsystem = '';          end
    if nargin < 5, useTimestamp = false;         end

    % modelName
    if ~(ischar(modelName) || isstring(modelName))
        error('PortExtractor:InvalidInput', 'modelName 必须是字符向量或字符串。');
    end
    modelName = char(modelName);

    % searchDepth
    validateattributes(searchDepth, {'numeric'}, ...
        {'scalar', 'integer', 'positive', 'real'}, ...
        'PortExtractor', 'searchDepth');

    % includeTriggerEnable
    if ~(islogical(includeTriggerEnable) || (isnumeric(includeTriggerEnable) && isscalar(includeTriggerEnable)))
        error('PortExtractor:InvalidInput', 'includeTriggerEnable 必须是逻辑值。');
    end
    includeTriggerEnable = logical(includeTriggerEnable);

    % startSubsystem
    if ~(ischar(startSubsystem) || isstring(startSubsystem))
        error('PortExtractor:InvalidInput', 'startSubsystem 必须是字符向量或字符串。');
    end
    startSubsystem = strtrim(char(startSubsystem));

    % useTimestamp
    if ~(islogical(useTimestamp) || (isnumeric(useTimestamp) && isscalar(useTimestamp)))
        error('PortExtractor:InvalidInput', 'useTimestamp 必须是逻辑值。');
    end
    useTimestamp = logical(useTimestamp);

    if ~bdIsLoaded(modelName)
        error('PortExtractor:ModelNotLoaded', ...
            '模型 "%s" 未加载。请先用 load_system 加载。', modelName);
    end

    %% ---------- 确定搜索起点 ----------
    if isempty(startSubsystem)
        searchRoot = modelName;
        rootLabel = '根模型';
    else
        searchRoot = [modelName '/' startSubsystem];
        rootLabel = searchRoot;
        try
            get_param(searchRoot, 'BlockType');
        catch
            error('PortExtractor:SubsystemNotFound', '未找到路径 "%s"。', searchRoot);
        end
    end

    %% ---------- 直接搜索各个端口类型 ----------
    % 注意：find_system 系统选项(SearchDepth/FollowLinks)必须放在块参数(BlockType)之前
    sysOpts = {'SearchDepth', searchDepth, 'FollowLinks', 'on'};



    % --- 输入端口 ---
    rawIn = find_system(searchRoot, sysOpts{:}, 'BlockType', 'Inport');
    numIn = numel(rawIn);
    inportNames = cell(numIn, 1);
    inportTypes = cell(numIn, 1);
    for i = 1:numIn
        inportNames{i} = get_param(rawIn{i}, 'Name');
        inportTypes{i} = get_param(rawIn{i}, 'OutDataTypeStr');
    end

    % --- 输出端口 ---
    rawOut = find_system(searchRoot, sysOpts{:}, 'BlockType', 'Outport');
    numOut = numel(rawOut);
    outportNames = cell(numOut, 1);
    outportTypes = cell(numOut, 1);
    for i = 1:numOut
        outportNames{i} = get_param(rawOut{i}, 'Name');
        outportTypes{i} = get_param(rawOut{i}, 'OutDataTypeStr');
    end

    % --- Trigger / Enable（可选）---
    if includeTriggerEnable
        % Trigger
        rawTr = find_system(searchRoot, sysOpts{:}, 'BlockType', 'TriggerPort');
        for i = 1:numel(rawTr)
            inportNames{end+1, 1} = get_param(rawTr{i}, 'Name');       %#ok<AGROW>
            inportTypes{end+1, 1} = get_param(rawTr{i}, 'TriggerType');%#ok<AGROW>
        end
        % Enable
        rawEn = find_system(searchRoot, sysOpts{:}, 'BlockType', 'EnablePort');
        for i = 1:numel(rawEn)
            inportNames{end+1, 1} = get_param(rawEn{i}, 'Name');   %#ok<AGROW>
            inportTypes{end+1, 1} = {'boolean'};                    %#ok<AGROW>
        end
    end

    % 更新端口数
    numIn = numel(inportNames);

    %% ---------- 构建表格 ----------
    varNames = {'序号', '端口名称', '数据类型', '指定数据类型', 'StorageClass', 'Identifier'};
    varTypes = {'double', 'cell', 'cell', 'cell', 'cell', 'cell'};

    emptyT = table('Size', [0, 6], 'VariableTypes', varTypes, 'VariableNames', varNames);

    if numIn > 0
        tIn = table((1:numIn)', inportNames, inportTypes, ...
            cell(numIn,1), cell(numIn,1), cell(numIn,1), ...
            'VariableNames', varNames);
    else
        tIn = emptyT;
    end

    if numOut > 0
        tOut = table((1:numOut)', outportNames, outportTypes, ...
            cell(numOut,1), cell(numOut,1), cell(numOut,1), ...
            'VariableNames', varNames);
    else
        tOut = emptyT;
    end

    if numIn == 0 && numOut == 0
        error('PortExtractor:NoPorts', '未找到任何 Inport 或 Outport。');
    end

    %% ---------- 写入 Excel ----------
    if useTimestamp
        ts = datestr(now, 'yyyymmdd_HHMMSS');
        filename = sprintf('ports_%s_%s.xlsx', modelName, ts);
    else
        filename = sprintf('ports_%s.xlsx', modelName);
        % 删除旧文件，避免残留数据影响新写入
        if exist(filename, 'file')
            delete(filename);
        end
    end
    writetable(tIn,  filename, 'Sheet', 'Inputs');
    writetable(tOut, filename, 'Sheet', 'Outputs');

    %% ---------- 摘要 ----------
    teFlag = '';
    if includeTriggerEnable, teFlag = ' (含Trigger/Enable)'; end

    fprintf('\n══════════ PortExtractor 完成 ══════════\n');
    fprintf('  模型:       %s\n', modelName);
    fprintf('  起始:       %s\n', rootLabel);
    fprintf('  搜索深度:   %d\n', searchDepth);
    fprintf('  Trigger:    %s\n', bool2str(includeTriggerEnable));
    fprintf('  ──────────────────────────\n');
    fprintf('  输入端口%s: %d\n', teFlag, numIn);
    fprintf('  输出端口:   %d\n', numOut);
    fprintf('  ──────────────────────────\n');
    fprintf('  输出:       %s\n', fullfile(pwd, filename));
    fprintf('════════════════════════════════════\n\n');

    if nargout > 0
        varargout{1} = fullfile(pwd, filename);
    end

end

function s = bool2str(x)
    if x, s = '是'; else, s = '否'; end
end
