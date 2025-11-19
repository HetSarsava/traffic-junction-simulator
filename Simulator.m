function traffic_simulation_stats()
    % We wrap this in a function so the variables don't clutter your workspace
    
    hFig = figure('Color',[0 0 0], 'Name', 'Traffic Data Collection (Running 10 Loops...)');
    hold on;
    axis equal off;

    % --- 1. Map Setup ---
    map_size = 60;
    road_width = 6;
    center = map_size / 2;
    xlim([0 map_size]);
    ylim([0 map_size]);

    % Intersection Zone
    int_start = center - (road_width/2);
    int_end   = center + (road_width/2);

    rectangle('Position', [int_start, 0, road_width, map_size], 'FaceColor', [0.1 0.1 0.1], 'EdgeColor', 'none');
    rectangle('Position', [0, int_start, map_size, road_width], 'FaceColor', [0.1 0.1 0.1], 'EdgeColor', 'none');

    hCar1 = rectangle('Position',[0 0 0 0], 'FaceColor','b', 'EdgeColor','none');
    hCar2 = rectangle('Position',[0 0 0 0], 'FaceColor','r', 'EdgeColor','none');

    % --- 2. Simulation Parameters ---
    speed = 15;
    dt = 0.05;
    total_runs = 10;
    
    % --- DATA STORAGE ---
    % We will store data for every car (2 cars * 10 loops = 20 records)
    % Rows: [Wait Time, Total Time]
    all_car_data = []; 

    % --- 3. THE MAIN LOOP (Run 10 times) ---
    for run_count = 1:total_runs
        
        if ~ishandle(hFig), break; end % Stop if user closes window
        
        % --- A. Scenario Setup ---
        car_w = 0.7 * road_width;
        car_l = 2 * car_w;
        
        % Define 4 directions: [StartX, StartY, W, L, Vx, Vy]
        cfg_B = [center-car_w/2, 0, car_w, car_l, 0, 1];
        cfg_L = [0, center-car_w/2, car_l, car_w, 1, 0];
        cfg_T = [center-car_w/2, map_size-car_l, car_w, car_l, 0, -1];
        cfg_R = [map_size-car_l, center-car_w/2, car_l, car_w, -1, 0];
        
        configs = {cfg_B, cfg_L, cfg_T, cfg_R};
        names   = {'Bottom', 'Left', 'Top', 'Right'};
        pairs   = [1 2; 2 3; 3 4; 4 1];
        
        % Pick random pair
        pair_idx = randi(4);
        p1_idx = pairs(pair_idx, 1);
        p2_idx = pairs(pair_idx, 2);
        
        % Init Car 1
        c1_cfg = configs{p1_idx};
        c1_pos = [c1_cfg(1), c1_cfg(2)]; c1_dim = [c1_cfg(3), c1_cfg(4)]; c1_vel = [c1_cfg(5), c1_cfg(6)];
        
        % Init Car 2
        c2_cfg = configs{p2_idx};
        c2_pos = [c2_cfg(1), c2_cfg(2)]; c2_dim = [c2_cfg(3), c2_cfg(4)]; c2_vel = [c2_cfg(5), c2_cfg(6)];
        
        delay = 0.4 + (rand * 0.8);
        sim_time = 0;
        
        if rand > 0.5, t1_start=0; t2_start=delay; else, t1_start=delay; t2_start=0; end

        title(sprintf('Run %d/%d | %s vs %s', run_count, total_runs, names{p1_idx}, names{p2_idx}), 'Color', 'w');
        
        % --- TIMERS FOR THIS RUN ---
        c1_wait = 0; c1_total = 0;
        c2_wait = 0; c2_total = 0;

        % --- B. Animation Loop ---
        cars_active = true;
        while cars_active && ishandle(hFig)
            sim_time = sim_time + dt;
            
            % Sensors
            c1_cent = c1_pos + c1_dim/2;
            c2_cent = c2_pos + c2_dim/2;
            c1_in_int = (c1_cent(1) > int_start-1 && c1_cent(1) < int_end+1) && (c1_cent(2) > int_start-1 && c1_cent(2) < int_end+1);
            c2_in_int = (c2_cent(1) > int_start-1 && c2_cent(1) < int_end+1) && (c2_cent(2) > int_start-1 && c2_cent(2) < int_end+1);
            
            % Move Car 1
            if sim_time > t1_start
                c1_total = c1_total + dt; % Track existence time
                
                % Calculate dist based on direction
                if c1_vel(2)==1, d=int_start-(c1_pos(2)+c1_dim(2)); elseif c1_vel(2)==-1, d=c1_pos(2)-int_end; elseif c1_vel(1)==1, d=int_start-(c1_pos(1)+c1_dim(1)); else, d=c1_pos(1)-int_end; end
                
                if (d > 0 && d < 2) && c2_in_int
                    c1_wait = c1_wait + dt; % Track wait time
                else
                    c1_pos = c1_pos + (c1_vel * speed * dt);
                end
            end
            
            % Move Car 2
            if sim_time > t2_start
                c2_total = c2_total + dt; % Track existence time
                
                if c2_vel(2)==1, d=int_start-(c2_pos(2)+c2_dim(2)); elseif c2_vel(2)==-1, d=c2_pos(2)-int_end; elseif c2_vel(1)==1, d=int_start-(c2_pos(1)+c2_dim(1)); else, d=c2_pos(1)-int_end; end
                
                if (d > 0 && d < 2) && c1_in_int
                    c2_wait = c2_wait + dt; % Track wait time
                else
                    c2_pos = c2_pos + (c2_vel * speed * dt);
                end
            end

            hCar1.Position = [c1_pos c1_dim];
            hCar2.Position = [c2_pos c2_dim];
            drawnow;
            pause(dt);
            
            c1_out = c1_pos(1)<-10 || c1_pos(1)>70 || c1_pos(2)<-10 || c1_pos(2)>70;
            c2_out = c2_pos(1)<-10 || c2_pos(1)>70 || c2_pos(2)<-10 || c2_pos(2)>70;
            if c1_out && c2_out, cars_active = false; end
        end
        
        % --- SAVE DATA FOR THIS RUN ---
        % Append [WaitTime, TotalTime] for both cars to the master list
        all_car_data = [all_car_data; c1_wait, c1_total; c2_wait, c2_total];
        
        if ishandle(hFig), pause(0.2); end
    end
    
    % --- 4. FINAL CALCULATIONS & REPORT ---
    if isempty(all_car_data), return; end
    
    % A. Total cars (Rows in our data)
    total_cars = size(all_car_data, 1);
    
    % B. Find cars that actually waited (Wait Time > 0)
    waiters_indices = all_car_data(:,1) > 0.01; % using 0.01 to avoid floating point errors
    num_waiters = sum(waiters_indices);
    
    % C. Calculate % Wait for ONLY the waiters
    % (WaitTime / TotalTime) * 100
    waiter_percentages = (all_car_data(waiters_indices, 1) ./ all_car_data(waiters_indices, 2)) * 100;
    avg_wait_pct_waiters = mean(waiter_percentages);
    
    % D. Calculate % Wait for ALL cars (including those with 0 wait)
    all_percentages = (all_car_data(:, 1) ./ all_car_data(:, 2)) * 100;
    avg_wait_pct_all = mean(all_percentages);
    
    % Print to Command Window
    fprintf('\n============================================\n');
    fprintf('SIMULATION REPORT (10 Runs)\n');
    fprintf('============================================\n');
    fprintf('Total Simulation Loops:       %d\n', total_runs);
    fprintf('Total Cars processed:         %d\n', total_cars);
    fprintf('Number of cars that waited:   %d\n', num_waiters);
    fprintf('--------------------------------------------\n');
    fprintf('Avg Wait Time (Waiters only): %.2f%%\n', avg_wait_pct_waiters);
    fprintf('Avg Wait Time (All Cars):     %.2f%%\n', avg_wait_pct_all);
    fprintf('============================================\n');
    
    % Show in a Message Box
    msg = sprintf(['Total Loops: %d\n' ...
                   'Cars that had to wait: %d\n\n' ...
                   'Avg Wait (Waiters Only): %.1f%%\n' ...
                   'Avg Wait (All Cars): %.1f%%'], ...
                   total_runs, num_waiters, avg_wait_pct_waiters, avg_wait_pct_all);
    msgbox(msg, 'Simulation Complete');
end