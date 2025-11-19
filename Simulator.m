hFig = figure('Color',[0 0 0], 'Name', 'Traffic Simulation - Random Intervals');
hold on;
axis equal off;

% --- 1. Setup Static Map ---
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

% --- 2. Setup Cars ---
car_w = 0.7 * road_width;
car_l = 2 * car_w;

hCar1 = rectangle('Position', [0,0,0,0], 'FaceColor', 'b', 'EdgeColor', 'none');
hCar2 = rectangle('Position', [0,0,0,0], 'FaceColor', 'b', 'EdgeColor', 'none');

velocity = 15;
dt = 0.05;
stop_line = int_start - car_l - 1;

% --- 3. INFINITE LOOP ---
while ishandle(hFig)
    
    % Reset Positions
    c1_x = center - (car_w/2); c1_y = 0;
    c2_x = 0;                  c2_y = center - (car_w/2);
    sim_time = 0;
    
    % --- RANDOMIZE THE INTERVAL ---
    % Previous version: danger_delay = 0.8; (Fixed)
    % New version: Random between 0.4s and 1.2s
    danger_delay = 0.4 + (rand * 0.8); 
    
    % Randomize Priority
    if rand > 0.5
        start_time_1 = 0;
        start_time_2 = danger_delay;
        prio = 'Bottom';
    else
        start_time_1 = danger_delay;
        start_time_2 = 0;
        prio = 'Left';
    end
    
    if ishandle(hFig)
        title(sprintf('Priority: %s Car | Delay: %.2fs', prio, danger_delay), 'Color', 'w');
    end
    
    % --- RUN SCENARIO ---
    cars_on_screen = true;
    while cars_on_screen && ishandle(hFig)
        sim_time = sim_time + dt;
        
        % Sensors
        c1_in_int = (c1_y > int_start - 1) && (c1_y < int_end + 2);
        c2_in_int = (c2_x > int_start - 1) && (c2_x < int_end + 2);
        
        % Move Car 1
        if sim_time > start_time_1
            at_stop = (c1_y >= stop_line) && (c1_y < int_start);
            if at_stop && c2_in_int
                % Wait
            else
                c1_y = c1_y + (velocity * dt);
            end
        end
        
        % Move Car 2
        if sim_time > start_time_2
            at_stop = (c2_x >= stop_line) && (c2_x < int_start);
            if at_stop && c1_in_int
                % Wait
            else
                c2_x = c2_x + (velocity * dt);
            end
        end
        
        % Update Graphics
        hCar1.Position = [c1_x, c1_y, car_w, car_l];
        hCar2.Position = [c2_x, c2_y, car_l, car_w];
        
        drawnow;
        pause(dt);
        
        if (c1_y > map_size) && (c2_x > map_size)
            cars_on_screen = false;
        end
    end
    
    if ishandle(hFig), pause(0.5); end
end