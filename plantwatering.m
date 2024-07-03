clear all; close all;

fprintf('------------------------------------------------------------------------------------------\n\n')

disp('Waiting for Arduino connection to be established...');

% Define Constants and setup the Pins
soilSensorPin = 'A0'; 
pumpPin = 'D2'; 
buttonPin = 'D6'; 

dryValue = 3.6; % Threshold for dry soil
lightlyMoistValue = 3.0; % Threshold for wet but not too wet soil (moderate soil)
saturatedValue = 2.4; % Threshold for saturated soil

a = arduino('COM6', 'Nano3');
fprintf('Arduino connection established!\n\n');

pause(1.5) % Pause for 1.5 seconds before allowing user to start the system

fprintf(['Press the button on D6 to start the ' ...
    'automatic plant watering system.\n\n'])

% Configure Pins
configurePin(a, pumpPin, 'DigitalOutput');
configurePin(a, buttonPin, 'DigitalInput');

% Initialize arrays for data logging
%{
Initialize empty arrays with explicit dimensions for data logging.
NaT(0, 1) and NaN(0, 1) for the arrays pruvides clarity on structure, while [] 
creates empty arrays but without preallocating memory for their size.
%}
timestamps = NaT(0, 1);
moistureLevels = NaN(0, 1);
moisturePercentages = NaN(0, 1);

% Initialize system states
systemRunning = false;
prevButtonState = 0;

while true
    
    buttonState = readDigitalPin(a, buttonPin);
    
    % Toggle systemRunning state on button press
    if buttonState == 1 && prevButtonState == 0
        systemRunning = ~systemRunning;
    end
    
    prevButtonState = buttonState;

    if systemRunning
        soilMoistureVoltage = readVoltage(a, soilSensorPin);
        soilMoisturePercentage = convertToMoisturePercentage(soilMoistureVoltage, dryValue, saturatedValue);

        timestamps = [timestamps; datetime('now')]; % Log current time
        moistureLevels = [moistureLevels; soilMoistureVoltage];
        moisturePercentages = [moisturePercentages; soilMoisturePercentage];

        % Determine state and act accordingly (Original Logic)
        if soilMoistureVoltage > dryValue
            writeDigitalPin(a, pumpPin, 1); % Turn on pump
            fprintf('Soil is very dry! Initiating watering. Voltage: %.1f\n\n', soilMoistureVoltage);
        elseif soilMoistureVoltage > lightlyMoistValue
            writeDigitalPin(a, pumpPin, 1); % Turn on pump
            fprintf('Soil is wet but not too wet. Continue watering. Voltage: %.1f\n\n', soilMoistureVoltage);
        elseif soilMoistureVoltage > saturatedValue
            writeDigitalPin(a, pumpPin, 0); % Turn off pump
            fprintf('Soil is sufficiently wet. Stopping water. Voltage: %.1f\n\n', soilMoistureVoltage);
        else
            writeDigitalPin(a, pumpPin, 0); % Condition incase of an error. Turn off pump
            fprintf('ERROR: Invalid soil moisture reading.\n\n');
            continue;
        end

        % Plot the data
        figure(1);
        plot(timestamps, moisturePercentages, 'b', 'LineWidth', 1);
        ylim([0 100]);
        xlabel('Time (HH:MM:SS)');
        ylabel('Soil Wetness Percentage (%)');
        title('Soil Wetness Percentage Over Time (Live Data)');
        grid("on");

        drawnow; % Update the plot
    end

    % Stop the loop if the button is pressed again to turn off the system
    
    if buttonState == 1 && systemRunning == false
        writeDigitalPin(a, pumpPin, 0); % Turn off pump
        fprintf(['The system has been shut down.\nNo automatic watering will happen, ' ...
            'and the poor plant will wither away. :(\n\n']);
        disp('------------------------------------------------------------------------------------------')
        break;
    end
end

function percentage = convertToMoisturePercentage(voltage, dryValue, saturatedValue)
    % Soil Moisture Percentage = m * Voltage + b, fits the standard form y=mx+c, 
    % where y is the dependent variable (Soil Moisture Percentage) and 
    % x is the independent variable (Voltage).

    % 2.4 V = 100% Soil Wetness (as recorded with sensor immersed in a clear glass of water)
    % 3.6 V = 0% Soil Wetness (as recorded with sensor not immersed in anything (air))
    
    % m = ΔSoil Moisture / ΔVoltage = (100% −0%) / (2.4V − 3.6V)

    m = (100 - 0) / (saturatedValue - dryValue);

    % Solving for c with points (3.6, 0): 0% = −83.33 * 3.6V + c
    
    c = (m * dryValue) * -1;

    percentage = m * voltage + c;
end