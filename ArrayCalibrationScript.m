%   _____                       _     
%  |  __ \                     ( )    
%  | |  | | __ _ _ __ ___ _   _|/ ___ 
%  | |  | |/ _` | '__/ __| | | | / __|
%  | |__| | (_| | | | (__| |_| | \__ \
%  |_____/ \__,_|_|  \___|\__, | |___/
%                          __/ |      
%                         |___/                                 
%      /\                         
%     /  \   _ __ _ __ __ _ _   _ 
%    / /\ \ | '__| '__/ _` | | | |
%   / ____ \| |  | | | (_| | |_| |
%  /_/    \_\_|  |_|  \__,_|\__, |
%                            __/ |
%                           |___/ 
%    _____      _ _ _               _   _             
%   / ____|    | (_) |             | | (_)            
%  | |     __ _| |_| |__  _ __ __ _| |_ _  ___  _ __  
%  | |    / _` | | | '_ \| '__/ _` | __| |/ _ \| '_ \ 
%  | |___| (_| | | | |_) | | | (_| | |_| | (_) | | | |
%   \_____\__,_|_|_|_.__/|_|  \__,_|\__|_|\___/|_| |_|
%                                                     
%    _____          _      
%   / ____|        | |     
%  | |     ___   __| | ___ 
%  | |    / _ \ / _` |/ _ \
%  | |___| (_) | (_| |  __/
%   \_____\___/ \__,_|\___|
         

%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
%//////////////////////////////////////////////////////////////////////////
% Setup
%//////////////////////////////////////////////////////////////////////////
%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
                         
    % --------------------------------------------------------------------
    % Set up key constants
    %----------------------------------------------------------------------
    % For controlling how the program runs overall
    checkSteps = 1;     % Determines whether or not to plot key data at each
                        % processing step for illustration / debugging 

    saveFlag = 1;       % Determines whether to save the resulting calibration data at the end of execution

    
    % General
    c = 1499.4;         % SoS [m/s] (tank was 26 degrees on example experiment day)

    % For windowing - you will likely have to change these parameters if
    % modifying this code to work with other data
    wLen = 80;          % Length of window [samples] 
    wPos = 0.46;        % Where in window should peak value go? [fraction of wLen]
    cosf = 0.5;         % Cosine fraction of tukey window
    yWinStart = 1935;   % Start time [samples] for constant y scan window

    % For resampling and padding
    fsNew = 50e6;       % Final sampling rate [Hz] - should match PAM data 
    NNew = 50e3;        % Final record length [samples @ fsNew] - should match PAM data

    % For setting frequency band
    fBand = [4e6 14e6]; % Start and stop frequencies [Hz] of frequency range of interest (array bandwidth) 

    %----------------------------------------------------------------------
    % Load hydrophone x scan data (prefix 'x')
    %----------------------------------------------------------------------
    load('HydrophoneXScan.mat');
    xScanData = detrend(rf,0);  % Detrend data to remove any dc bias

    N = length(xScanData);      % N = Record length [samples]
    xL = size(xScanData,2);     % xL = Number of locations in x scan 
                                % (i.e. number of elements in array)
    t = (0:N-1)/fs;             % Time vector [s]

    %----------------------------------------------------------------------
    % Load hydrophone y scan data (prefix 'y')
    %----------------------------------------------------------------------
    load('HydrophoneYScan.mat');
    yScanData = detrend(rf,0);
    yL = size(yScanData,2);     % yL = Number of locations in y scan

    %----------------------------------------------------------------------
    % Load array recording data (prefix 'a')
    %----------------------------------------------------------------------
    load('ArrayRecording.mat');
    aData = detrend(rf,0);

    %----------------------------------------------------------------------
    % Load hydrophone sensitivity and directivity
    %----------------------------------------------------------------------
    % Sensitivity
    load('HydrophoneSensitivity.mat');

    % Directivity
    load('HydrophoneDirectivity.mat');


%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
%//////////////////////////////////////////////////////////////////////////
%% Window Hydrophone Data
%//////////////////////////////////////////////////////////////////////////
%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

    % --------------------------------------------------------------------
    % Window data to remove long periods of background noise and any
    % non-scattered sound arriving directly from focused transducer
    % --------------------------------------------------------------------
    % Create tukey window
    win = tukeywin(wLen,cosf);       % win is just the wLen point long 
                                     % tukey window, it needs to be
                                     % positioned at the right point in 
                                     % a time vector in order to select
                                     % just the pulse

    r = round(cosf*0.5*wLen);        % r is time [samples] the window takes 
                                     % to fully ramp up and down at edges

    sigWin = zeros(size(xScanData)); % sigWin is the 'signal window' 
                                     % It has one column for each 
                                     % recording in the x scan, equals win
                                     % during the recorded pulse and 0 at 
                                     % all other time points

    noiseWin = sigWin;               % noiseWin covers a patch of initial 
                                     % noise in each recording (of the same 
                                     % length as the signal window), for 
                                     % SNR analysis
     
    %----------------------------------------------------------------------
    % Window the x scan
    %----------------------------------------------------------------------
    % Find peak in x recording at each scan location, calculate start and 
    % stop time indices for window covering that peak
    [~,pks] = max(xScanData,[],1);
    pksSmooth = round(movmean(pks,3));         % Apply a mild moving average to smooth out bumps in window locations
    xStartInds = pksSmooth - round(wLen*wPos);
    xStopInds = xStartInds + wLen - 1;

    % Create arrays containing windows for each location
    % sigWin covers where the actual pulse is (the signal)

    for ii = 1:xL
        sigWin(xStartInds(ii):xStopInds(ii),ii) = win;
        noiseWin(1:wLen,ii) = win;
    end

    % Apply windows by element-wise multiplication
    xDataWin = xScanData .* sigWin;
    xDataNoise = xScanData.* noiseWin;

    %----------------------------------------------------------------------
    % Window the array data - same process as above
    %----------------------------------------------------------------------
    [~,pks] = max(aData,[],1);
    pksSmooth = round(movmean(pks,3));         
    aStartInds = pksSmooth - round(wLen*wPos);
    aStopInds = aStartInds + wLen - 1;

    sigWin = zeros(size(aData));
    noiseWin = sigWin;

    for ii = 1:xL
        sigWin(aStartInds(ii):aStopInds(ii),ii) = win;
        noiseWin(1:wLen,ii) = win;
    end

    % Apply windows by element-wise multiplication
    aDataWin = aData .* sigWin;
    aDataNoise = aData.* noiseWin;

    %----------------------------------------------------------------------
    % Repeat windowing process for y scan data, but since wavefront so much
    % less curved over this scan aperture, just use constant window
    % location
    %----------------------------------------------------------------------
    sigWin = zeros(N,1);
    noiseWin = sigWin;
    sigWin(yWinStart:yWinStart-1+wLen) = win;
    noiseWin(1:wLen) = win;

    yDataWin = yScanData .* sigWin;
    yDataNoise = yScanData .* noiseWin;


            % % Check step: plot raw hydrophone data for x and y scans with
            % % the window start and end times overlayed
            % % 
            % % If the windows are placed correctly, the entire pulse
            % % should fit between the red and yellow lines
            if checkSteps
                figure; xAx = gca();  
                xPts = (-63.5:63.5)*0.3;    % x Scan locations [mm]
                imagesc(xPts,t,xScanData);
                colormap("gray");
                title('Check 1: Hydrophone x Data and Window Locations');
                xlabel('x Location [mm]');
                ylabel('Time (s)');
                ylim([3.7e-5 4.6e-5]);

                hold(xAx,'on');
                plot(xAx,xPts,[t(xStartInds);t(xStartInds+r);t(xStopInds-r);t(xStopInds)])
                legend('Window Start','Window Start + r','Window End - r','Window End')

                figure; yAx = gca();
                yPts = (-8:8)*0.3;        % y Scan locations [mm] 
                imagesc(yPts,t,yScanData);
                colormap("gray");
                title('Check 1: Hydrophone y Data and Window Locations');
                xlabel('y Location [mm]');
                ylabel('Time (s)');
                ylim([3.8e-5 4.07e-5]);

                hold(yAx,'on');
                plot(yAx,yPts,[t(yWinStart);t(yWinStart+r);t(yWinStart-1+wLen-r);t(yWinStart-1+wLen)].*ones(size(yPts)))
                legend('Window Start','Window Start + r','Window End - r','Window End')

                figure; aAx = gca();
                imagesc(xPts,t,aData);
                colormap("gray");
                title('Check 1: Array Data and Window Locations');
                xlabel('x Location [mm]');
                ylabel('Time (s)');
                ylim([3.7e-5 4.6e-5]);

                hold(aAx,'on');
                plot(aAx,xPts,[t(aStartInds);t(aStartInds+r);t(aStopInds-r);t(aStopInds)])
                legend('Window Start','Window Start + r','Window End - r','Window End')

            end


    %----------------------------------------------------------------------
    % Check SNR
    %----------------------------------------------------------------------
            % % Check step: plot magnitude spectra and SNR of all 3 
            % % datasets (hydrophone x, y, and array) to check for any nulls
            % % or other areas of low signal, and see what frequency range
            % % the data is useful over.
            if checkSteps
                % Hydrophone x scan data
                xSpec = fft(xDataWin);
                xNoiseSpec = fft(xDataNoise);
                xSNR = mag2db(abs(xSpec./xNoiseSpec));  % [dB re V]
                fOld = (0:N-1)*fs/N;                    % frequency vector [Hz]
                                                        % called fOld as this is before
                                                        % any resampling and padding

                figure, subplot(1,2,1)
                imagesc(xPts,fOld/1e6,abs(xSpec./max(xSpec(:))));
                title('Check 2: Spectrum of Hydrophone x scan data');
                ylim(fBand/1e6);
                xlabel('x Location [mm]')
                ylabel('Frequency [MHz]')
                cb = colorbar;
                ylabel(cb, 'Normalized Amplitude');
                
                subplot(1,2,2)
                imagesc(xPts,fOld/1e6,xSNR);
                title('SNR of Hydrophone x scan data');
                ylim(fBand/1e6);
                xlabel('x Location [mm]')
                ylabel('Frequency [MHz]')
                cb = colorbar;
                ylabel(cb, 'SNR [dB]'),clim([0 20]);

                % Make window wider
                pos = gcf().Position;
                set(gcf(),'Position',pos .* [0.5 1 2 1])

                % Hydrophone y scan data
                ySpec = fft(yDataWin);
                yNoiseSpec = fft(yDataNoise);
                ySNR = mag2db(abs(ySpec./yNoiseSpec)); 
                
                figure, subplot(1,2,1)
                imagesc(yPts,fOld/1e6,abs(ySpec./max(ySpec(:))));
                title('Check 2: Spectrum of Hydrophone y scan data');
                ylim(fBand/1e6);
                xlabel('y Location [mm]')
                ylabel('Frequency [MHz]')
                cb = colorbar;
                ylabel(cb, 'Normalized Amplitude');
                
                subplot(1,2,2)
                imagesc(yPts,fOld/1e6,ySNR);
                title('SNR of Hydrophone y scan data');
                ylim(fBand/1e6);
                xlabel('y Location [mm]')
                ylabel('Frequency [MHz]')
                cb = colorbar;
                ylabel(cb, 'SNR [dB]'),clim([0 20]);

                % Make window wider
                pos = gcf().Position;
                set(gcf(),'Position',pos .* [0.5 1 2 1])


                % Array data
                aSpec = fft(aDataWin);
                aNoiseSpec = fft(aDataNoise);
                aSNR = mag2db(abs(aSpec./aNoiseSpec)); 

                figure, subplot(1,2,1)
                imagesc(xPts,fOld/1e6,abs(aSpec./max(aSpec(:))));
                title('Check 3: Spectrum of array recording data');
                ylim(fBand/1e6);
                xlabel('x Location [mm]')
                ylabel('Frequency [MHz]')
                cb = colorbar;
                ylabel(cb, 'Normalized Amplitude');
                
                subplot(1,2,2)
                imagesc(xPts,fOld/1e6,aSNR);
                title('SNR of array recording');
                ylim(fBand/1e6);
                xlabel('x Location [mm]')
                ylabel('Frequency [MHz]')
                cb = colorbar;
                ylabel(cb, 'SNR [dB]'),clim([0 20]);

                % Make window wider
                pos = gcf().Position;
                set(gcf(),'Position',pos .* [0.5 1 2 1])


            end



%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
%//////////////////////////////////////////////////////////////////////////
%% Resample and Pad Hydrophone Data (if necessary)
%//////////////////////////////////////////////////////////////////////////
%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

% For calibration to be useful, the hydrophone recordings, array recording,
% and future rf data to be beamformed all need the same: 
% - Sampling rate (fsNew) and
% - Record length (NNew)

% If you know what these parameters will be ahead of time, you can make
% sure they're all the same at the time of recording. Otherwise, the data
% will all need to be resampled to fsNew then zero padded or truncated to
% NNew.

    %----------------------------------------------------------------------
    % Resample hydrophone data to fsNew
    %----------------------------------------------------------------------
    % (MATLAB's resample function includes anti-aliasing filter so no need
    % to do this separately)
    [xDataResampled,~] = resample(xDataWin,t,fsNew);
    [yDataResampled,~] = resample(yDataWin,t,fsNew);
    [aDataResampled,~] = resample(aDataWin,t,fsNew);
    Nres = size(xDataResampled,1);        % Nres = record length after resample but before zero pad

    %----------------------------------------------------------------------
    % Pad / truncate hydrophone data to NNew
    %----------------------------------------------------------------------
    % If record length needs to be longer, zero pad ends of hydrophone
    %  recordings
    if (NNew >= Nres)
        xPad = zeros(NNew-Nres,xL); 
        yPad = zeros(NNew-Nres,yL);
        
        xDataPadded = [xDataResampled;xPad];
        yDataPadded = [yDataResampled;yPad];
        aDataPadded = [aDataResampled;xPad];

    % Otherwise, crop off end of each recording
    % (Still just called xDataPadded even when not padded because I'm only
    % human)
    else
        xDataPadded = xDataResampled(1:NNew,:);
        yDataPadded = yDataResampled(1:NNew,:);
        aDataPadded = aDataResampled(1:NNew,:);
    end

    % Take Fourier transforms of padded and resampled data
    xSpec = fft(xDataPadded);
    ySpec = fft(yDataPadded);
    aSpec = fft(aDataPadded);

    tNew = (0:NNew-1)/fsNew;         % Create new time vector [s]
    fNew = (0:NNew-1)*(fsNew/NNew);  % Create new frequency vector [Hz]

    % Note that I don't bother with shifting arround the fft spectrum or 
    % including negative frequencies in the frequency vector, so the values
    % in fNew are only correct for f = 0 : Nyquist. (The negative frequency
    % range -Nyquist : 0 gets mapped to Nyquist : 2 * Nyquist in this
    % vector).

                % % Check step: verify padded and resampled signals match
                % % originals in time and frequency domain
                if checkSteps
                    % Create spectrum and frequency vector for data that
                    % has been windowed but not padded or resampled
                    xSpecWin = fft(xDataWin);
                    fWin = (0:length(xSpecWin)-1)*(fs/length(xSpecWin));
                    figure;

                    for ii = 1:10:xL
                        % Plot time domain data
                        subplot(2,1,1)
                        plot(t,xDataWin(:,ii));
                        hold on;
                        plot(tNew,xDataPadded(:,ii),'r.');
                        hold off;
                        xlim([t(xStartInds(ii)) t(xStopInds(ii))]);
                        leg = legend('xDataWin','xDataPadded');
                        leg.Title.String = 'Time Domain';
                        title('Check 3: x Scan data before and after resampling and padding')
                        xlabel('Time [s]');
                        ylabel('Hydrophone Output [V]');

                        subplot(2,1,2)
                        plot(fWin/1e6,abs(xSpecWin(:,ii)))
                        hold on;
                        plot(fNew/1e6,abs(xSpec(:,ii)),'r--');
                        leg = legend('xDataWin','xDataPadded');
                        leg.Title.String = 'Frequency Domain';
                        hold off;
                        xlabel('Frequency [MHz]');
                        ylabel('Hydrophone Output Spectrum');
                        xlim(fBand/1e6);
                        title(sprintf('Scan Position %i',ii))
                        pause(0.5)
                    end
                end

%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
%//////////////////////////////////////////////////////////////////////////
%% Calculate Spatial Averaging Factor Sp from Hydrophone y Scan Data
%//////////////////////////////////////////////////////////////////////////
%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

    %----------------------------------------------------------------------
    % Account for hydrophone directivity
    %----------------------------------------------------------------------

    % Directivity function H (and Hinv = 1/H) were measured in the xz
    % plane, but assume directivity pattern is the same in the yz plane.
    % Since y scan is short and example hydrophone is very
    % omnidirectional, effect of directivity here is small, but it can be
    % accounted for so we should.

    % Take just central yL points from the directivity measurement, this
    % assumes that your x and y scans have the same pitch
    yPointsRange = floor(xL/2)+1 - floor(yL/2) : floor(xL/2)+1 + floor(yL/2); 
    
    % Account for hydrophone directivity at each point in y scan.
    % Multiply by Hinv instead of dividing by H as measured hydrophone
    % directivity has some very low values in it, which blow up when
    % inverted. Hinv is 1 / H but preprocessed with a cap on how large 
    % these values can get.
    yDirCorr = ySpec .* Hinv(:,yPointsRange);

    % No need to account for hydrophone's sensitivity Mphone here since it 
    % is constant with position and will be divided out.

    %----------------------------------------------------------------------
    % Spatially average y scan data over element height in elevation
    % direction (5mm for L11-5 example)
    %----------------------------------------------------------------------

    % Take spatial average of y scan data at each frequency across
    % element height
    ySpatialAve = mean(ySpec,2);    
    yCentre = ySpec(:,floor(yL/2) + 1);

    % Create spatial averaging factor Sp(f) by dividing spatially 
    % averaged y spectrum by centre y spectrum - this scaling factor 
    % will be multiplied into the x scan data to convert the (effectively)
    % point measurements into average pressures across the element face.
    Sp = ySpatialAve ./ yCentre;

    % Note that Sp can be greater than one if the pressure field has a
    % bimodal shape at a particular frequency, where pressure is low in the
    % centre and higher outside.

                % % Check step: plot Sp for all frequencies in frequency
                % band of interest
                if checkSteps
                    figure;
                    yyaxis left
                    plot(fNew/1e6,abs(Sp))
                    ylim([0 1.2])
                    ylabel('Magnitude of Sp [unitless]')
                    yyaxis right
                    plot(fNew/1e6,angle(Sp))
                    ylabel('Phase of Sp [rad]')
                    xlim(fBand/1e6);
                    title({'Check 4: How does spatial average pressure compare';'to pressure at y = 0?'})
                end

%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
%//////////////////////////////////////////////////////////////////////////
%% Convert Hydrophone Voltages to Pressures
%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
%//////////////////////////////////////////////////////////////////////////

    pAve = xSpec .* Sp .* Hinv ./ (Mphone * 1e6);   % Average pressure 
                                                    % across the face of
                                                    % each array element
                                                    % [MPa]
    
    % Multiply by Hinv instead of dividing by H as measured hydrophone
    % directivity has some very low values in it, which blow up when
    % inverted. Hinv is 1 / H but with a cap on how large these values can
    % get.

    % Mphone is in units of [V / Pa], here I multiply by 1e6 to get pAve in
    % units of [MPa], personal preference.


            % Check step: Take inverse fourier transform and see how 
            % pressure signal looks

            % Calibrated time domain signal should have amplitudes in the
            % range of 10s - 100s of kPa for a wire-scattered field, will
            % likely show a higher noise floor. This is likely just high
            % frequency noise boosted by applying the correction factors
            % and therefore isn't an issue, since it's outside the f band
            % of interest
            if checkSteps
                pt = ifft(pAve,'symmetric');   % pAve [MPa] in time-domain 
    
                figure;
                for ii = 1:10:128                                    
                    plot(tNew,pt(:,ii)*1e3)
                    [~,cen] = max(pt(:,ii));
                    xlim([tNew(cen)-1e-6 tNew(cen)+1e-6]);
                    title(sprintf('Check 5: Calibrated Pressure Signal at Scan Location %i',ii));
                    xlabel('Time [s]');
                    ylabel('pAve [kPa]');
                    drawnow;
                    pause(0.5);
                end
            end

   
%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
%//////////////////////////////////////////////////////////////////////////
%% Calculate MH: Divide Array's Voltage Output by Average Pressure Input 
%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
%//////////////////////////////////////////////////////////////////////////


    %----------------------------------------------------------------------
    % Divide array spectra by hydrophone's pressure spectrum, calculating
    % array alpha value (combined sensitivity and directivity)
    %----------------------------------------------------------------------

    MHraw = aSpec ./ pAve;  % [V / MPa]

    % % Check step: plot MHraw
    if checkSteps
        % Plot magnitude of MH -> broadband sensitivity of each element
        figure
        imagesc(1:xL,fNew/1e6,abs(MHraw))
        ylim(fBand/1e6);
        xlabel('Element Number')
        ylabel('Frequency [MHz]')
        title('Check 6: |MH|, Raw')
        clim([0 11e4]);
        c1 = colorbar;
        ylabel(c1,'Sensitivity [ADC units / MPa]');  
    
        % Plot angle of MH -> broadband phase shifts applied by each element
        figure
        imagesc(1:xL,fNew/1e6,angle(MHraw))
        ylim(fBand/1e6);
        xlabel('Element #')
        ylabel('Frequency (MHz)')
        title({'Check 6: Phase of MH, Raw'})
        c2 = colorbar;
        ylabel(c2,'Phase [rad]');
        
    end

%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
%//////////////////////////////////////////////////////////////////////////
%% Regularize MH and invert to get MHinv
%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
%//////////////////////////////////////////////////////////////////////////

    %----------------------------------------------------------------------
    % Place floor on how small MH values can be to prevent them blowing up
    % upon inversion, I use a threshold of 5% of the maximum value here
    %----------------------------------------------------------------------
    MHmax = 11e4; % Manual threshold for about what the largest actual 
                  % values of the sensitivity function are [ADC Units/MPa]
                  % Note that this is done by hand rather than with max(MH)
                  % as the function generally contains some artefactual
                  % spots with super high values that throw off the maximum

    % Define key for which elements/frequencies fall under 5% of max threshold
    key = abs(MHraw) < 0.05*MHmax;

    % Create MHbound, which equals MH but with a lower bound on how small
    % sensitivities can be.
    MHbound = MHraw;

    %----------------------------------------------------------------------
    % Scale all points with values below the threshold up to meet it. 
    %----------------------------------------------------------------------
    % Note: don't just replace MHbound(key) with 0.05*MHmax since this
    % would give a real number with zero phase, causing nasty phase jumps.
    % Instead, divide these values by their magnitudes then multiply by
    % 0.05*MHmax, which replaces magnitude but preserves phase.
    MHbound(key) = 0.05*MHmax * MHbound(key) ./ abs(MHbound(key));

    % Create MHinv
    MHinvBound = 1 ./ MHbound;

    % Check step: Plot the key of where the unacceptably low values are
    if checkSteps
        figure
        imagesc(1:xL,fNew/1e6,key)
        ylim(fBand/1e6);
        xlabel('Element Number')
        ylabel('Frequency [MHz]')
        title('Check 7: Key (= 1 where sensitivity below threshold)')
        c2 = colorbar;
    end

%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
%//////////////////////////////////////////////////////////////////////////
%% Taper Out MH Values for Frequencies Outside of Array Bandwidth
%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
%//////////////////////////////////////////////////////////////////////////

    % Since the calibration will eventually be applied to PAM recordings
    % via the frequency-domain multiplication P(f) = V(f) .* MHinv(f), 
    % we can add a bandpass filtering effect to MHinv by tapering its
    % values down to zero at the edges of the frequency band of interest,
    % eliminating a lot of artefacts from useless data outside the f
    % band.

    % Find indices of frequencies closest to desired f band start and end
    % points, in case there isn't a perfect match in the fNew vector
    [~,indStart] = min(abs(fNew-fBand(1)));
    [~,indEnd] = min(abs(fNew-fBand(2)));
    indBand = indStart:indEnd;

    % Create window covering frequency band of interest
    bandwin = zeros(NNew,1);
    bandwin(indBand) = tukeywin(length(indBand),0.25);
    bandwin = bandwin + flip(bandwin);    % Include negative frequencies too!
                                    % Recall that MH was created with
                                    % 2-sided fft spectra, meaning there is
                                    % a flipped conjugate version of the
                                    % sensitivity spectrum after the
                                    % positive frequencies we have been
                                    % plotting.

    % Apply window
    MHinvWin = MHinvBound .* bandwin;
    MHwin = MHbound .* bandwin;

    % No check plot here, see next step

%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
%//////////////////////////////////////////////////////////////////////////
%% Remove Array Elements' Directive Nulls from MHinv Spectrum
%\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
%//////////////////////////////////////////////////////////////////////////

    % Additionally, for short axial distances and high frequencies, as in
    % this example data, the outer elements will exhibit directive nulls,
    % where sensitivity is ~0 at some frequency-angle combinations.

    % Two approaches can be taken to these nulls: 1) leave them in the
    % sensitivity correction, which has the downside of noise being
    % amplified by the low sensitivity (i.e. high MHinv) at these points or
    % 2) Cut out the nulls by tapering off the frequency band of each
    % element individually, and starting the taper just before the null
    % begins for each element. This has the downside that each element's
    % signals now contain energy over a different bandwidth, complicating
    % decisions about how to ensure your PAM is energy-preserving.

    % This example code shows how to do option 2), if you want option 1),
    % just omit these final steps.

    % Find first time (after 5 MHz) that MH is below the 5% of max
    % threshold for each element. This assumes that the only reason the
    % sensitivity drops that low above 5 MHz is that the element is in a
    % directive null.
    [~,ind5] = min(abs(fNew-5e6));

    % Creating a new window of different length for each element would mean
    % they all have a different slope of rolloff (assuming constant cosine
    % fraction). Therefore instead, just make one Tukey window to define
    % the rolloff rate and shift it around to define the cutoff frequency.

    nullWinLen = round(length(indBand)/4); % Number of points in window for positioning
    nullwin = tukeywin(nullWinLen, 0.25); % Only the upper edge of this window will
                                       % be used.

    nullRemover = zeros(size(MHraw));  % Array to hold positioned windows for each element

    for ii = 1:xL
        % Find first instance of key = 1 (i.e. MH < 0.5 * MHmax) after 5MHz 
        indNull = ind5-1 + find(key(ind5:end,ii),1);  

        % If this criterion isn't met, or is only met above the band of
        % interest, set the endpoint to just below the Nyquist frequency so
        % it's well out of the way, and the upper frequency range will just
        % be determined by the constant cutoff set in the previous step.
        if isempty(indNull) || fNew(indNull) > fBand(2)
            indNull = floor(NNew/2)-1;
        end

        % Find the middle index of the null window, everything up to this
        % frequency will be replaced with ones since we don't need to do
        % anything extra to the low-frequncy side.
        indMid = indNull - round(nullWinLen/2);

        % Create the window
        nullRemover(indNull-nullWinLen+1:indNull,ii) = nullwin; % Place window so it tapers down to zero at indNull
        nullRemover(1:indMid,ii) = 1;                           % Remove all effects on low fequencies
        nullRemover(:,ii) = nullRemover(:,ii) + flip(nullRemover(:,ii));    % Include negative frequencies in window

    end

    % Remove nulls by applying variable-start windows
    MHinv = MHinvWin .* nullRemover;
    MH = MHwin .* nullRemover;

    % % Check step: plot spectra of |MH| with: no changes, constant
    % bandwidth taper, and null removal
    if checkSteps

        figure, subplot(1,3,1);
        imagesc([],fNew/1e6,abs(MHraw));
        ylim(fBand/1e6);
        clim([0 11e4]);
        xlabel('Element Number')
        ylabel('Frequency [MHz]')
        title('|MH|, Raw')
        cb = colorbar;
        ylabel(cb,'Sensivity [ADC Units / MPa]')

        subplot(1,3,2)
        imagesc([],fNew/1e6,abs(MHwin));
        ylim(fBand/1e6);
        clim([0 11e4]);
        xlabel('Element Number')
        ylabel('Frequency [MHz]')
        cb = colorbar;
        ylabel(cb,'Sensivity [ADC Units / MPa]')
        title({'Check 8: Effects of Limiting MH Band and Removing Nulls';'|MH|, High and Low f Removed'})


        subplot(1,3,3);
        imagesc([],fNew/1e6,abs(MH));
        ylim(fBand/1e6);
        clim([0 11e4]);
        xlabel('Element Number')
        ylabel('Frequency [MHz]')
        cb = colorbar;
        ylabel(cb,'Sensivity [ADC Units / MPa]')
        title('|MH|, Nulls Removed')
        
        % Make window wider
        pos = gcf().Position;
        set(gcf(),'Position',pos .* [0.5 1 2 1])

    end

    if saveFlag
        fCal = fNew;
        fsCal = fsNew;
        NCal = NNew;
        calInfo = {'Combined experimental correction factors for PAM array Sensitivity [M] and Directivity [H]';
                   'Apply calibration by element-wise multiplication with MHinv in frequency domain: Pressure(f) = ArrayVoltage(f) .* MHinv(f)';
                   'ArrayVoltage data must have record length = NCal and sampling frequency = fsCal';
                   ' ';
                   'MH [MPa / ADC Units] is combined sensitivity and directivity, each row is a frequency, each column is an array element';
                   'MHinv [ADC Units / MPa] is 1./MH but with regularization applied before inversion to prevent small values blowing up very large';
                   'fsCal [Hz] is required sampling frequency for applying this calibration data';
                   'NCal [samples] is required record length for applying this calibration data';
                   'fCal [Hz] holds the frequencies corresponding to each row of MH (& MHinv). Note negative frequencies (f) expressed as (2*fNyquist - f)';
                   'El_pos [m] holds the locations of the array elements (lateral direction) corresponding to each column of MH (& MHinv).';
                   };

        save('ArrayCal.mat','MHinv','MH','fsCal','NCal','fCal','NCal','calInfo');
    end
