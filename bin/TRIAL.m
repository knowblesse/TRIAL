classdef ManualVideoTracker_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        TRIALUIFigure             matlab.ui.Figure
        FileMenu                  matlab.ui.container.Menu
        OpenVideoMenu             matlab.ui.container.Menu
        StartTrackingMenu         matlab.ui.container.Menu
        LoadPreviousDataMenu      matlab.ui.container.Menu
        SaveMenu                  matlab.ui.container.Menu
        OptionMenu                matlab.ui.container.Menu
        ChangePointerMouseMenu    matlab.ui.container.Menu
        ChangePointerCrossMenu    matlab.ui.container.Menu
        ChangePointerHandMenu     matlab.ui.container.Menu
        AboutMenu                 matlab.ui.container.Menu
        AboutMenu_2               matlab.ui.container.Menu
        Image                     matlab.ui.control.Image
        CurrentFrameSpinnerLabel  matlab.ui.control.Label
        CurrentFrameSpinner       matlab.ui.control.Spinner
        VideoSlider               matlab.ui.control.Slider
        CurrentTime               matlab.ui.control.Label
        StepLabel                 matlab.ui.control.Label
        GoFirstFrame              matlab.ui.control.Button
        GoLastFrame               matlab.ui.control.Button
        RunInterpolationButton    matlab.ui.control.StateButton
        ShowInterpDataCheckBox    matlab.ui.control.CheckBox
        DropDown                  matlab.ui.control.DropDown
    end

    
    properties (Access = private)
        videoPath; % Description
        videoreader;
        numberofframe;
        currentframe;
        step;
        locationdata;
        flag_tracking;
        DOT_SIZE = 5;
        CROSS_SIZE = 8;
    end
    methods (Access = private)
        
        function changeCurrentFrame(app,frame)
            app.Image.Enable = false;
            app.currentframe = frame;
            
            % Spinner
            app.CurrentFrameSpinner.Value = frame;
            
            % Time Label
            timeInSec = (1 / app.videoreader.FrameRate) * frame;
            time_minute = floor(timeInSec / 60);
            time_second = timeInSec - (time_minute * 60);
            app.CurrentTime.Text = strcat(...
                num2str(time_minute,'%02.0f'),...
                ':',...
                num2str(time_second,'%06.3f')...
                );
            
            % Slider
            app.VideoSlider.Value = frame;
            
            % Show the frame
            img2draw = read(app.videoreader, frame);
                     
            % plot red dot
            if (app.locationdata(app.currentframe,5) ~= 0) % location 
                for i = -app.DOT_SIZE : app.DOT_SIZE
                    for j = -app.DOT_SIZE : app.DOT_SIZE
                        if app.inrange(app.locationdata(app.currentframe,1) + i, app.videoreader.Width, 1) && ...
                                app.inrange(app.locationdata(app.currentframe,2) + j, app.videoreader.Height, 1)
                            try
                            img2draw(...
                                app.videoreader.Height - app.locationdata(app.currentframe,2) + 1 + i,... % Row (height - y + 1)
                                app.locationdata(app.currentframe,1) + j,... % Column (x)
                                :) = [255,0,0];     
                            catch
                                disp(app.videoreader.Height - app.locationdata(app.currentframe,2) + 1 + i);
                                disp(app.locationdata(app.currentframe,1) + j);
                            end
                        end
                    end
                end
            end
            
            % plot green cross (interp data)
            if (app.ShowInterpDataCheckBox.Value)
                for i = -app.CROSS_SIZE : app.CROSS_SIZE
                    if app.inrange(app.locationdata(app.currentframe,3) + i, app.videoreader.Width, 1) && ...
                                app.inrange(app.locationdata(app.currentframe,4), app.videoreader.Height, 1)
                        img2draw(...
                            app.videoreader.Height - app.locationdata(app.currentframe,4) + 1 + i,... % Row (height - y + 1)
                            app.locationdata(app.currentframe,3),... % Column (x)
                            :) = [0,255,0];     
                    end
                end
                for j = -app.CROSS_SIZE : app.CROSS_SIZE
                    if app.inrange(app.locationdata(app.currentframe,3), app.videoreader.Width, 1) && ...
                            app.inrange(app.locationdata(app.currentframe,4) + j, app.videoreader.Height, 1)
                        img2draw(...
                            app.videoreader.Height - app.locationdata(app.currentframe,4) + 1,... % Row (height - y + 1)
                            app.locationdata(app.currentframe,3) + j,... % Column (x)
                            :) = [0,255,0];     
                    end
                end
            end
            
            app.Image.ImageSource = img2draw;
            app.Image.Enable = true;
        
        end
        function result = inrange(~, number, max_value, min_value)
        % include the edge
            if and(number >= min_value, number <= max_value)
                result = true;
            else
                result = false;
            end
            
        end
        
        function interpolateData(app)
            if(app.locationdata(1,5) == 0)
                errordlg('The first frame is not labelled. Can not interpolate.');
            elseif(app.locationdata(end,5) == 0)
                errordlg('The last frame is not labelled. Can not interpolate.');
            else
                labeled_index = find(app.locationdata(:,5) == 1);
                for i = 1 : numel(labeled_index)-1
                    i_start = labeled_index(i);
                    i_end = labeled_index(i+1);
                    itp_x = interp1(...
                        [i_start,i_end],...
                        [app.locationdata(i_start,1), app.locationdata(i_end,1)],...
                        i_start:i_end,...
                        app.DropDown.Value);
                    itp_y = interp1(...
                        [i_start,i_end],...
                        [app.locationdata(i_start,2), app.locationdata(i_end,2)],...
                        i_start:i_end,...
                        app.DropDown.Value);
                    app.locationdata(i_start:i_end,3:4) = round([itp_x',itp_y']);
                end
                app.ShowInterpDataCheckBox.Enable = true;
            end
            
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.flag_tracking = false;
            app.StartTrackingMenu.Enable = false;
            app.SaveMenu.Enable = false;
            app.LoadPreviousDataMenu.Enable = false;
            app.step = 5;
            app.StepLabel.Visible = false;
            app.CurrentFrameSpinner.Enable = false;
            app.VideoSlider.Enable = false;
            app.ShowInterpDataCheckBox.Enable = false;
            app.GoFirstFrame.Enable = false;
            app.GoLastFrame.Enable = false;
            app.RunInterpolationButton.Enable = false;
            app.DropDown.Enable = false;
        end

        % Menu selected function: OpenVideoMenu
        function OpenVideoButtonPushed(app, event)
            [filename, path] = uigetfile('*.mp4',"Select Video to process");
            if filename ~= 0
                app.videoPath = strcat(path, filename);
                app.videoreader = VideoReader(app.videoPath);
                app.numberofframe = app.videoreader.NumberOfFrames;
                
                % video
                app.videoreader = VideoReader(app.videoPath);
                
                msgbox({...
                    strcat('Video Name : ', filename),...
                    strcat('Frame Rate : ', num2str(app.videoreader.FrameRate)),...
                    strcat('Dimension : ', num2str(app.videoreader.Width), ' x ', num2str(app.videoreader.Height)),...
                    strcat('Duration of one Frame : ', num2str(1/app.videoreader.FrameRate), 'seconds'),...
                    strcat('Number of Frame : ', num2str(app.numberofframe))...
                    });
                
                app.VideoSlider.Limits = [1, app.numberofframe];
                app.VideoSlider.MajorTicks = 1 : app.videoreader.FrameRate * 60 : app.numberofframe;
                app.VideoSlider.MajorTickLabels = cellstr(num2str((0 : numel(app.VideoSlider.MajorTicks))'));
                
                app.Image.ImageSource = read(app.videoreader,1);
                app.Image.Position(3:4) = [app.videoreader.Width, app.videoreader.Height];
                
                app.currentframe = 1;
                
                %% Get the total locationdata size
                app.locationdata = zeros(app.numberofframe,5); % real X, real Y, interpol X, interpol Y, iseditted
                
                app.StartTrackingMenu.Enable = true;
                app.StepLabel.Visible = true;
                app.SaveMenu.Enable = true;
                app.LoadPreviousDataMenu.Enable = true;
                app.CurrentFrameSpinner.Enable = true;
                app.VideoSlider.Enable = true;
                app.GoFirstFrame.Enable = true;
                app.GoLastFrame.Enable = true;
                app.RunInterpolationButton.Enable = true;
                app.DropDown.Enable = true;
                app.ShowInterpDataCheckBox.Enable = false;
            end    
        end

        % Menu selected function: AboutMenu_2
        function AboutMenu_2Selected(app, event)
            msgbox({'2021 Knowblesse', 'to save GH'});
        end

        % Menu selected function: StartTrackingMenu
        function StartTrackingMenuSelected(app, event)
            app.flag_tracking = true;
        end

        % Key release function: TRIALUIFigure
        function TRIALUIFigureKeyRelease(app, event)
            key = event.Key;
            if(app.flag_tracking)
                target = get(0, 'PointerLocation') - (app.TRIALUIFigure.Position(1:2) +app.Image.Position(1:2));
                
                x = target(1);
                y = target(2);
                switch key
                    case 'rightarrow'
                        if and(app.inrange(x,app.videoreader.Width,1), app.inrange(y,app.videoreader.Height,1))
                            app.locationdata(app.currentframe,1:2) = round([x,y]);    
                            app.locationdata(app.currentframe,5) = 1;  
                        end
                        if app.currentframe + app.step > app.numberofframe
                            msgbox('The last step');
                        else
                            app.currentframe = app.currentframe + app.step;
                            app.changeCurrentFrame(app.currentframe);
                        end
                    case 'leftarrow'
                        if and(app.inrange(x,app.videoreader.Width,1), app.inrange(y,app.videoreader.Height,1))
                            app.locationdata(app.currentframe,1:2) = round([x,y]);    
                            app.locationdata(app.currentframe,5) = 1;  
                        end
                        if app.currentframe - app.step < 1 
                            msgbox('The first step');
                        else
                            app.currentframe = app.currentframe - app.step;
                            app.changeCurrentFrame(app.currentframe);
                        end
                    case 'uparrow'
                        app.step = app.step + 1;
                        app.StepLabel.Text = strcat('Step =  ', num2str(app.step));
                    case 'downarrow'
                        if app.step > 1
                            app.step = app.step - 1;
                            app.StepLabel.Text = strcat('Step =  ', num2str(app.step));
                        end
                end
            end
        end

        % Menu selected function: SaveMenu
        function SaveMenuSelected(app, event)
        filename_candidate = strcat(app.videoPath,'_data.csv');
        if exist(filename_candidate,'file') > 0 % numbered filename
            filename_number = 1;
            isfilenamefixed = false;
            filename_candidate = strcat(app.videoPath,'_data(',num2str(filename_number),').csv');
            while ~isfilenamefixed
                if exist(filename_candidate,'file') > 0
                    filename_number = filename_number + 1;
                    filename_candidate = strcat(app.videoPath,'_data(',num2str(filename_number),').csv');
                else
                    filename = filename_candidate;
                    isfilenamefixed = true;
                end    
            end
        else
            filename = filename_candidate;
        end
        
        try
            writematrix(app.locationdata, filename);    
        catch 
            warndlg('Can not write the file');
        end
        
        end

        % Value changed function: CurrentFrameSpinner
        function CurrentFrameSpinnerValueChanged(app, event)
            value = app.CurrentFrameSpinner.Value;
            app.changeCurrentFrame(round(value));
        end

        % Value changed function: VideoSlider
        function VideoSliderValueChanged(app, event)
            value = app.VideoSlider.Value;
            app.changeCurrentFrame(round(value));
        end

        % Menu selected function: LoadPreviousDataMenu
        function LoadPreviousDataMenuSelected(app, event)
            [filename, path] = uigetfile('*.csv',"Select Datafile csv to process");
            if filename ~= 0    
                 rmat = readmatrix(strcat(path,filename));
                 if isequal(size(rmat), [app.numberofframe,5])
                    app.locationdata = rmat;    
                 else
                     errordlg('Data file size mismatch');
                 end
            end
        end

        % Button pushed function: GoFirstFrame
        function GoFirstFrameButtonPushed(app, event)
            app.changeCurrentFrame(1);
        end

        % Button pushed function: GoLastFrame
        function GoLastFrameButtonPushed(app, event)
            app.changeCurrentFrame(app.numberofframe);
        end

        % Value changed function: DropDown, RunInterpolationButton
        function RunInterpolationButtonValueChanged(app, event)
            app.interpolateData();
            app.changeCurrentFrame(app.currentframe);
        end

        % Value changed function: ShowInterpDataCheckBox
        function ShowInterpDataCheckBoxValueChanged(app, event)
            value = app.ShowInterpDataCheckBox.Value;
            if value
                app.interpolateData();
                app.changeCurrentFrame(app.currentframe);
            end
            
        end

        % Menu selected function: ChangePointerMouseMenu
        function ChangePointerMouseMenuSelected(app, event)
            app.TRIALUIFigure.Pointer = 'arrow';
        end

        % Menu selected function: ChangePointerCrossMenu
        function ChangePointerCrossMenuSelected(app, event)
            app.TRIALUIFigure.Pointer = 'cross';
        end

        % Menu selected function: ChangePointerHandMenu
        function ChangePointerHandMenuSelected(app, event)
            app.TRIALUIFigure.Pointer = 'hand';
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create TRIALUIFigure and hide until all components are created
            app.TRIALUIFigure = uifigure('Visible', 'off');
            app.TRIALUIFigure.Position = [100 100 683 601];
            app.TRIALUIFigure.Name = 'TRIAL';
            app.TRIALUIFigure.KeyReleaseFcn = createCallbackFcn(app, @TRIALUIFigureKeyRelease, true);
            app.TRIALUIFigure.Pointer = 'cross';

            % Create FileMenu
            app.FileMenu = uimenu(app.TRIALUIFigure);
            app.FileMenu.Text = 'File';

            % Create OpenVideoMenu
            app.OpenVideoMenu = uimenu(app.FileMenu);
            app.OpenVideoMenu.MenuSelectedFcn = createCallbackFcn(app, @OpenVideoButtonPushed, true);
            app.OpenVideoMenu.Text = 'Open Video';

            % Create StartTrackingMenu
            app.StartTrackingMenu = uimenu(app.FileMenu);
            app.StartTrackingMenu.MenuSelectedFcn = createCallbackFcn(app, @StartTrackingMenuSelected, true);
            app.StartTrackingMenu.Text = 'Start Tracking';

            % Create LoadPreviousDataMenu
            app.LoadPreviousDataMenu = uimenu(app.FileMenu);
            app.LoadPreviousDataMenu.MenuSelectedFcn = createCallbackFcn(app, @LoadPreviousDataMenuSelected, true);
            app.LoadPreviousDataMenu.Text = 'Load Previous Data';

            % Create SaveMenu
            app.SaveMenu = uimenu(app.FileMenu);
            app.SaveMenu.MenuSelectedFcn = createCallbackFcn(app, @SaveMenuSelected, true);
            app.SaveMenu.Text = 'Save';

            % Create OptionMenu
            app.OptionMenu = uimenu(app.TRIALUIFigure);
            app.OptionMenu.Text = 'Option';

            % Create ChangePointerMouseMenu
            app.ChangePointerMouseMenu = uimenu(app.OptionMenu);
            app.ChangePointerMouseMenu.MenuSelectedFcn = createCallbackFcn(app, @ChangePointerMouseMenuSelected, true);
            app.ChangePointerMouseMenu.Text = 'Change Pointer : Mouse';

            % Create ChangePointerCrossMenu
            app.ChangePointerCrossMenu = uimenu(app.OptionMenu);
            app.ChangePointerCrossMenu.MenuSelectedFcn = createCallbackFcn(app, @ChangePointerCrossMenuSelected, true);
            app.ChangePointerCrossMenu.Text = 'Change Pointer : Cross';

            % Create ChangePointerHandMenu
            app.ChangePointerHandMenu = uimenu(app.OptionMenu);
            app.ChangePointerHandMenu.MenuSelectedFcn = createCallbackFcn(app, @ChangePointerHandMenuSelected, true);
            app.ChangePointerHandMenu.Text = 'Change Pointer : Hand';

            % Create AboutMenu
            app.AboutMenu = uimenu(app.TRIALUIFigure);
            app.AboutMenu.Text = 'About';

            % Create AboutMenu_2
            app.AboutMenu_2 = uimenu(app.AboutMenu);
            app.AboutMenu_2.MenuSelectedFcn = createCallbackFcn(app, @AboutMenu_2Selected, true);
            app.AboutMenu_2.Text = 'About';

            % Create Image
            app.Image = uiimage(app.TRIALUIFigure);
            app.Image.BackgroundColor = [0.7804 0.5059 0.4902];
            app.Image.Position = [23 103 640 480];
            app.Image.ImageSource = 'TRIAL_ÿÿ 1.png';

            % Create CurrentFrameSpinnerLabel
            app.CurrentFrameSpinnerLabel = uilabel(app.TRIALUIFigure);
            app.CurrentFrameSpinnerLabel.HorizontalAlignment = 'right';
            app.CurrentFrameSpinnerLabel.Position = [1 47 84 22];
            app.CurrentFrameSpinnerLabel.Text = 'Current Frame';

            % Create CurrentFrameSpinner
            app.CurrentFrameSpinner = uispinner(app.TRIALUIFigure);
            app.CurrentFrameSpinner.ValueDisplayFormat = '%.0f';
            app.CurrentFrameSpinner.ValueChangedFcn = createCallbackFcn(app, @CurrentFrameSpinnerValueChanged, true);
            app.CurrentFrameSpinner.Position = [88 47 84 22];
            app.CurrentFrameSpinner.Value = 1;

            % Create VideoSlider
            app.VideoSlider = uislider(app.TRIALUIFigure);
            app.VideoSlider.Limits = [0 1];
            app.VideoSlider.MajorTicks = [];
            app.VideoSlider.ValueChangedFcn = createCallbackFcn(app, @VideoSliderValueChanged, true);
            app.VideoSlider.MinorTicks = [];
            app.VideoSlider.Position = [332 57 318 3];

            % Create CurrentTime
            app.CurrentTime = uilabel(app.TRIALUIFigure);
            app.CurrentTime.HorizontalAlignment = 'center';
            app.CurrentTime.Position = [244 47 81 22];
            app.CurrentTime.Text = 'MM:SS.sss';

            % Create StepLabel
            app.StepLabel = uilabel(app.TRIALUIFigure);
            app.StepLabel.BackgroundColor = [0 0 0];
            app.StepLabel.HorizontalAlignment = 'center';
            app.StepLabel.FontSize = 20;
            app.StepLabel.FontColor = [1 1 1];
            app.StepLabel.Visible = 'off';
            app.StepLabel.Position = [552 103 111 24];
            app.StepLabel.Text = 'Step = 5';

            % Create GoFirstFrame
            app.GoFirstFrame = uibutton(app.TRIALUIFigure, 'push');
            app.GoFirstFrame.ButtonPushedFcn = createCallbackFcn(app, @GoFirstFrameButtonPushed, true);
            app.GoFirstFrame.Position = [172 47 30 22];
            app.GoFirstFrame.Text = '<<';

            % Create GoLastFrame
            app.GoLastFrame = uibutton(app.TRIALUIFigure, 'push');
            app.GoLastFrame.ButtonPushedFcn = createCallbackFcn(app, @GoLastFrameButtonPushed, true);
            app.GoLastFrame.Position = [205 47 30 22];
            app.GoLastFrame.Text = '>>';

            % Create RunInterpolationButton
            app.RunInterpolationButton = uibutton(app.TRIALUIFigure, 'state');
            app.RunInterpolationButton.ValueChangedFcn = createCallbackFcn(app, @RunInterpolationButtonValueChanged, true);
            app.RunInterpolationButton.Text = 'Run Interpolation';
            app.RunInterpolationButton.Position = [97 16 107 22];

            % Create ShowInterpDataCheckBox
            app.ShowInterpDataCheckBox = uicheckbox(app.TRIALUIFigure);
            app.ShowInterpDataCheckBox.ValueChangedFcn = createCallbackFcn(app, @ShowInterpDataCheckBoxValueChanged, true);
            app.ShowInterpDataCheckBox.Text = 'Show Interp. Data';
            app.ShowInterpDataCheckBox.Position = [207 16 118 22];

            % Create DropDown
            app.DropDown = uidropdown(app.TRIALUIFigure);
            app.DropDown.Items = {'linear', 'nearest', 'spline'};
            app.DropDown.ValueChangedFcn = createCallbackFcn(app, @RunInterpolationButtonValueChanged, true);
            app.DropDown.Position = [9 16 80 22];
            app.DropDown.Value = 'linear';

            % Show the figure after all components are created
            app.TRIALUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ManualVideoTracker_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.TRIALUIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.TRIALUIFigure)
        end
    end
end