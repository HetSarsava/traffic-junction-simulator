hFig = figure('Color',[0 0 0], 'Name', 'Traffic Sim - 4 Way Adjacent Spawn');
hold on;
axis equal off;

% --- 1. Setup Map ---
map_size = 60;
road_width = 6;
center = map_size / 2;
xlim([0 map_size]);
ylim([0 map_size]);

% Intersection Zone Boundaries
int_start = center - (road_width/2);
int_end   = center + (road_width/2);

% Draw Roads
rectangle('Position', [int_start, 0, road_width, map_size], 'FaceColor', [0.1 0.1 0.1], 'EdgeColor', 'none');
rectangle('Position', [0, int_start, map_size, road_width], 'FaceColor', [0.1 0.1 0.1], 'EdgeColor', 'none');

% --- 2. Initialize Graphic Objects ---
hCar1 = rectangle('Position',[0 0 0 0], 'FaceColor','b', 'EdgeColor','none');
hCar2 = rectangle('Position',[0 0 0 0], 'FaceColor','r', 'EdgeColor','none'); % Car 2 is Red now for contrast

% Global settings
speed = 15;
dt = 0.05;

% --- 3. INFINITE LOOP ---
while ishandle(hFig)
    
    % === A. SETUP SCENARIO ===
    
    % Define the 4 Starting configurations
    % Format: [StartX, StartY, Width, Length, VelX, VelY]
    car_w = 0.7 * road_width;
    car_l = 2 * car_w;
    
    % 1. Bottom (Moves Up)
    cfg_B = [center-car_w/2, 0, car_w, car_l, 0, 1];
    % 2. Left (Moves Right)
    cfg_L = [0, center-car_w/2, car_l, car_w, 1, 0];
    % 3. Top (Moves Down) - Note: Start Y is map_size - length
    cfg_T = [center-car_w/2, map_size-car_l, car_w, car_l, 0, -1];
    % 4. Right (Moves Left) - Note: Start X is map_size - length
    cfg_R = [map_size-car_l, center-car_w/2, car_l, car_w, -1, 0];
    
    configs = {cfg_B, cfg_L, cfg_T, cfg_R};
    names   = {'Bottom', 'Left', 'Top', 'Right'};
    
    % Select Random Adjacent Pair
    % Pairs: 1=Bot, 2=Left, 3=Top, 4=Right
    % Valid Adjacent: [1,2], [2,3], [3,4], [4,1]
    pairs = [1 2; 2 3; 3 4; 4 1];
    pair_idx = randi(4); % Pick one row
    
    p1_idx = pairs(pair_idx, 1);
    p2_idx = pairs(pair_idx, 2);
    
    % Apply Settings to Variables
    % Car 1
    c1_cfg = configs{p1_idx};
    c1_pos = [c1_cfg(1), c1_cfg(2)]; % x, y
    c1_dim = [c1_cfg(3), c1_cfg(4)]; % w, l
    c1_vel = [c1_cfg(5), c1_cfg(6)]; % vx, vy
    
    % Car 2
    c2_cfg = configs{p2_idx};
    c2_pos = [c2_cfg(1), c2_cfg(2)];
    c2_dim = [c2_cfg(3), c2_cfg(4)];
    c2_vel = [c2_cfg(5), c2_cfg(6)];
    
    % Random Start Delay
    delay = 0.4 + (rand * 0.8);
    sim_time = 0;
    
    % Random Priority
    if rand > 0.5
        t1_start = 0; t2_start = delay;
    else
        t1_start = delay; t2_start = 0;
    end
    
    % Update Title
    if ishandle(hFig)
        title(sprintf('%s vs %s (Delay: %.2fs)', names{p1_idx}, names{p2_idx}, delay), 'Color', 'w');
    end
    
    % === B. ANIMATION LOOP ===
    cars_active = true;
    while cars_active && ishandle(hFig)
        sim_time = sim_time + dt;
        
        % --- 1. Check Intersection Status ---
        % Is the center of the car roughly inside the intersection box?
        % We calculate center points for checking
        c1_cent = c1_pos + c1_dim/2;
        c2_cent = c2_pos + c2_dim/2;
        
        c1_in_int = (c1_cent(1) > int_start-1 && c1_cent(1) < int_end+1) && ...
                    (c1_cent(2) > int_start-1 && c1_cent(2) < int_end+1);
        
        c2_in_int = (c2_cent(1) > int_start-1 && c2_cent(1) < int_end+1) && ...
                    (c2_cent(2) > int_start-1 && c2_cent(2) < int_end+1);
        
        % --- 2. Move Car 1 ---
        if sim_time > t1_start
            % Calculate Distance to Intersection Entry
            dist = 999;
            if c1_vel(2) == 1       % Moving Up
                dist = int_start - (c1_pos(2) + c1_dim(2));
            elseif c1_vel(2) == -1  % Moving Down
                dist = c1_pos(2) - int_end;
            elseif c1_vel(1) == 1   % Moving Right
                dist = int_start - (c1_pos(1) + c1_dim(1));
            elseif c1_vel(1) == -1  % Moving Left
                dist = c1_pos(1) - int_end;
            end
            
            % Stop Logic: If close (0 to 2 units away) AND blocked
            if (dist > 0 && dist < 2) && c2_in_int
                % WAIT
            else
                c1_pos = c1_pos + (c1_vel * speed * dt);
            end
        end
        
        % --- 3. Move Car 2 ---
        if sim_time > t2_start
            % Calculate Distance to Intersection Entry
            dist = 999;
            if c2_vel(2) == 1       % Moving Up
                dist = int_start - (c2_pos(2) + c2_dim(2));
            elseif c2_vel(2) == -1  % Moving Down
                dist = c2_pos(2) - int_end;
            elseif c2_vel(1) == 1   % Moving Right
                dist = int_start - (c2_pos(1) + c2_dim(1));
            elseif c2_vel(1) == -1  % Moving Left
                dist = c2_pos(1) - int_end;
            end
            
            if (dist > 0 && dist < 2) && c1_in_int
                % WAIT
            else
                c2_pos = c2_pos + (c2_vel * speed * dt);
            end
        end

        % Update Graphics
        hCar1.Position = [c1_pos c1_dim];
        hCar2.Position = [c2_pos c2_dim];
        drawnow;
        pause(dt);
        
        % Check Exit (If both cars are out of bounds)
        % Bounds are -10 to 70 to be safe
        c1_out = c1_pos(1) < -10 || c1_pos(1) > 70 || c1_pos(2) < -10 || c1_pos(2) > 70;
        c2_out = c2_pos(1) < -10 || c2_pos(1) > 70 || c2_pos(2) < -10 || c2_pos(2) > 70;
        
        if c1_out && c2_out
            cars_active = false;
        end
    end
    if ishandle(hFig), pause(0.5); end
end