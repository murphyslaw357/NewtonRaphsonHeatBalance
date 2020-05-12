function conductorData = importfileAB(filename, startRow, endRow)
%IMPORTFILE2 Import numeric data from a text file as a matrix.
%   CONDUCTORDATA = IMPORTFILE2(FILENAME) Reads data from text file
%   FILENAME for the default selection.
%
%   CONDUCTORDATA = IMPORTFILE2(FILENAME, STARTROW, ENDROW) Reads data from
%   rows STARTROW through ENDROW of text file FILENAME.
%
% Example:
%   conductorData = importfile2('conductorData.csv', 2, 415);
%
%    See also TEXTSCAN.

% Auto-generated by MATLAB on 2019/04/01 08:08:33

%% Initialize variables.
delimiter = ',';
if nargin<=2
    startRow = 2;
    endRow = inf;
end

%% Format for each line of text:
%   column1: text (%q)
%	column2: double (%f)
%   column3: categorical (%C)
%	column4: double (%f)
%   column5: double (%f)
%	column6: double (%f)
%   column7: double (%f)
%	column8: double (%f)
%   column9: double (%f)
%	column10: double (%f)
%   column11: double (%f)
%	column12: double (%f)
%   column13: double (%f)
%	column14: double (%f)
%   column15: double (%f)
%	column16: double (%f)
%   column17: double (%f)
%	column18: double (%f)
%   column19: double (%f)
%	column20: text (%q)
%   column21: double (%f)
%	column22: double (%f)
%   column23: double (%f)
%	column24: double (%f)
%   column25: text (%q)
%	column26: double (%f)
%   column27: double (%f)
% For more information, see the TEXTSCAN documentation.
formatSpec = '%q%f%q%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%q%f%f%f%f%q%f%f%[^\n\r]';

%% Open the text file.
fileID = fopen(filename,'r');

%% Read columns of data according to the format.
% This call is based on the structure of the file used to generate this
% code. If an error occurs for a different file, try regenerating the code
% from the Import Tool.
dataArray = textscan(fileID, formatSpec, endRow(1)-startRow(1)+1, 'Delimiter', delimiter, 'TextType', 'string', 'EmptyValue', NaN, 'HeaderLines', startRow(1)-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');
for block=2:length(startRow)
    frewind(fileID);
    dataArrayBlock = textscan(fileID, formatSpec, endRow(block)-startRow(block)+1, 'Delimiter', delimiter, 'TextType', 'string', 'EmptyValue', NaN, 'HeaderLines', startRow(block)-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');
    for col=1:length(dataArray)
        dataArray{col} = [dataArray{col};dataArrayBlock{col}];
    end
end

%% Close the text file.
fclose(fileID);

%% Post processing for unimportable data.
% No unimportable data rules were applied during the import, so no post
% processing code is included. To generate code which works for
% unimportable data, select unimportable cells in a file and regenerate the
% script.

%% Create output variable
conductorData = table(dataArray{1:end-1}, 'VariableNames', {'CodeWord','Size','Stranding','IndDiamAl','IndDiamSt','DiamStlCore','DiamCompleteCable','Weightper1000ftAl','Weightper1000ftStl','Weightper1000ftTotal','Al','Stl','RatedStrength','ResistanceDCLowdegc','ResistanceACHighdegc','LowTemp','HighTemp','MetersperResistanceInterval','AllowableAmpacity','Type','ResistanceACLowdegc','ResistanceACLowdegcMeter','ResistanceACHighdegcMeter','simulated','polymodels','convergeCurrent','lowestRise'});

