classdef WellSamplesHM < BaseSamplesHM & WellSamples
    % Class that holds an ensemble of sampled well-related properties and
    % methods to apply such samples to a given problem. 
    % For use with an MRSTEnsemble.
    %
    % DESCRIPTION:
    %   This class is an extention of `BaseSamples` and is used within a 
    %   MRSTEnsemble to organize stochastic well properties. These well 
    %   properties can either be pre-computed or generated on the fly.
    % 
    % SYNOPSIS
    %   samples = WellSamples('data', data);
    %   samples = WellSamples('generatorFn', generatorFn);
    %
    % OPTIONAL PARAMETERS
    %   'data' - precomputed sample data. Supported formats:
    %               * Cell array of data samples
    %               * Instance of ResultHandler class with
    %                 information about storage location and names. See
    %                 ResultHandler class for details
    %
    %   'generatorFn' - Function for generating a stochastic sample
    %
    %   'wells' - Names or indices of wells that the samples should be
    %             applied to.
    % 
    % NOTE:
    %   Either 'data' or 'generatorFn' must be provided.
    %   Each sample should consist of a struct with the fields that are
    %   also found in the typical well schedule struct in MRST.
    %
    % SEE ALSO:
    %   `RockSamples`, `DeckSamples`, `BaseSamples`, `MRSTExample`, `BaseQoI`
    

    
    methods
        function samples = WellSamplesHM(varargin)
            samples = samples@WellSamples(varargin{:});
        end
        
        %-----------------------------------------------------------------%
        % Functions related to history matching
        %-----------------------------------------------------------------%
        function sampleVectors = getSampleVectors(samples)

            assert(~isempty(samples.data), ...
                'This function only work with pre-generated samples');
            
            
            wellIsField = isfield(samples.data{1}, 'well');
            if wellIsField
                sampleFields = fieldnames(samples.data{1}.well);
                numWells = numel(samples.data{1}.well.(sampleFields{1}));
            else
                sampleFields = fieldnames(samples.data{1});
                numWells = numel(samples.data{1}.(sampleFields{1}));
            end
            numFields = numel(sampleFields);
            
            sampleVectors = zeros(numFields*numWells, samples.num);
            
            for i = 1:samples.num
                for f = 1:numFields
                    field = sampleFields{f};
                    startIndex = (f-1)*numWells + 1;
                    endIndex   = f*numWells;
                    
                    if wellIsField
                        fieldData = samples.data{i}.well.(field);
                    else
                        fieldData = samples.data{i}.(field);
                    end
                    
                    if strcmp(field, 'WI') && samples.transformSampleVectors
                        % Logarithmic transform of well production indices
                         sampleVectors(startIndex:endIndex, i)= log(fieldData);
                    else
                        sampleVectors(startIndex:endIndex, i) = fieldData;
                    end
                end
            end
        end
        
        %-----------------------------------------------------------------%
        function samples = setSampleVectors(samples, newSampleVectors)
            
            assert(size(newSampleVectors, 2) == samples.num, ...
                'number of columns of new samples does not match ensemble size');
            
            wellIsField = isfield(samples.data{1}, 'well');
            if wellIsField
                sampleFields = fieldnames(samples.data{1}.well);
                numWells = numel(samples.data{1}.well.(sampleFields{1}));
            else
                sampleFields = fieldnames(samples.data{1});
                numWells = numel(samples.data{1}.(sampleFields{1}));
            end
            numFields = numel(sampleFields);
            
            assert(size(newSampleVectors, 1) == numWells*numFields, ...
                'number of rows of new sample does not match old sample size');
            
            for i = 1:samples.num
                for f = 1:numFields
                    field = sampleFields{f};
                    startIndex = (f-1)*numWells + 1;
                    endIndex   = f*numWells;

                    if strcmp(field, 'WI') && samples.transformSampleVectors
                        % Logarithmic transform of well production indices
                        fieldData = exp(newSampleVectors(startIndex:endIndex, i));
                    else
                        fieldData = newSampleVectors(startIndex:endIndex, i);
                    end
                    
                    if wellIsField
                        samples.data{i}.well.(field)(:) = fieldData;
                    else
                        samples.data{i}.(field)(:) = fieldData;
                    end
                end
            end           
        end
        
        
        
    end
end
