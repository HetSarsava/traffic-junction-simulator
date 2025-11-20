function TwoWayTrafficSim()
    % 1. Setup Figure and Map
    hFig = figure('Color',[0.2 0.2 0.2], 'Name', 'Two-Way Traffic (Collision Avoidance)');
    axis equal off;
    hold on;
    
    % --- Map Constants ---
    map_size = 100;
    road_width = 14;       
    lane_width = road_width / 2;
    center = map_size / 2;
    
    % Intersection Boundaries (The "Danger Zone")
    int_min = center - road_width/2;
    int_max = center + road_width/2;
    
    xlim([0 map_size]);
    ylim([0 map_size]);
    
    % --- Draw Roads ---
    rectangle('Position', [int_min, 0, road_width, map_size], ...
              'FaceColor', [0.4 0.4 0.4], 'EdgeColor', 'none');
    rectangle('Position', [0, int_min, map_size, road_width], ...
              'FaceColor', [0.4 0.4 0.4], 'EdgeColor', 'none');
    % Draw Intersection Box (Visual aid for the "Box")
    rectangle('Position', [int_min, int_min, road_width, road_width], ...
              'FaceColor', [0.35 0.35 0.35], 'EdgeColor', 'w', 'LineStyle', ':');
          
    % --- Draw Dashed Center Lines ---
    plot([center center], [0 map_size], 'w--', 'LineWidth', 1);
    plot([0 map_size], [center center], 'w--', 'LineWidth', 1);
    
    % --- 2. Simulation Settings ---
    cars = struct('h', {}, 'pos', {}, 'dim', {}, 'vel', {}); 
    
    car_w = 3;
    car_l = 5;
    speed = 20;
    dt = 0.05;
    safe_dist = 8; % Distance to keep from car in front
    
    spawn_timer = 0;
    spawn_interval = 1.5; 
    
    fprintf('Simulation started with Collision Avoidance.\n');
    
    % --- 3. Main Loop ---
    while ishandle(hFig)
        spawn_timer = spawn_timer + dt;
        
        % --- A. Spawning Logic ---
        if spawn_timer > spawn_interval
            spawn_timer = 0; 
            spawn_interval = 0.5 + (rand * 1.0); % Slightly faster for testing
            
            offset = lane_width / 2;
            
            % Define Spawns: [Start X, Start Y, Vel X, Vel Y, Color]
            cfg_Bot = {center + offset, -5,          0,  1,  'b'}; 
            cfg_Top = {center - offset, map_size+5,  0, -1,  'r'};
            cfg_Lft = {-5,              center - offset, 1,  0,  'g'};
            cfg_Rgt = {map_size+5,      center + offset, -1, 0,  'y'};
            
            options = {cfg_Bot, cfg_Top, cfg_Lft, cfg_Rgt};
            pick = options{randi(4)};
            
            vx = pick{3}; vy = pick{4}; col = pick{5};
            
            if vx == 0, w = car_w; l = car_l; else, w = car_l; l = car_w; end
            
            start_pos = [pick{1} - w/2, pick{2} - l/2];
            
            % Check if spawn point is clear before adding (prevent spawn crash)
            spawn_clear = true;
            for k=1:length(cars)
                if norm(cars(k).pos - start_pos) < 10, spawn_clear = false; break; end
            end
            
            if spawn_clear
                hNew = rectangle('Position', [start_pos, w, l], 'FaceColor', col, 'EdgeColor', 'k');
                new_car.h = hNew;
                new_car.pos = start_pos;
                new_car.dim = [w, l];
                new_car.vel = [vx, vy];
                cars(end+1) = new_car;
            end
        end
        
        % --- B. Movement & Logic Loop ---
        for i = length(cars):-1:1
            c = cars(i);
            can_move = true; % Assume green light unless logic says STOP
            
            % --------------------------------------------
            % LOGIC 1: Rear-End Collision Avoidance
            % --------------------------------------------
            for j = 1:length(cars)
                if i == j, continue; end % Don't check self
                other = cars(j);
                
                % Are we in the same lane? (Simple check: same velocity direction)
                if isequal(c.vel, other.vel)
                    % Calculate distance
                    dist_vec = other.pos - c.pos;
                    dist = norm(dist_vec);
                    
                    % Check if 'other' is IN FRONT based on velocity
                    is_front = false;
                    if c.vel(1) == 1 && dist_vec(1) > 0, is_front = true; end  % Right
                    if c.vel(1) == -1 && dist_vec(1) < 0, is_front = true; end % Left
                    if c.vel(2) == 1 && dist_vec(2) > 0, is_front = true; end  % Up
                    if c.vel(2) == -1 && dist_vec(2) < 0, is_front = true; end % Down
                    
                    % If in front and too close -> BRAKE
                    if is_front && dist < safe_dist
                        can_move = false;
                    end
                end
            end
            
            % --------------------------------------------
            % LOGIC 2: Intersection Yield (The Box)
            % --------------------------------------------
            if can_move % Only check this if we aren't already stuck behind a car
                
                % 1. Am I approaching the Stop Line?
                dist_to_entry = 999;
                % Right-moving car approach Left line
                if c.vel(1)==1,  dist_to_entry = int_min - (c.pos(1)+c.dim(1)); end 
                % Left-moving car approach Right line
                if c.vel(1)==-1, dist_to_entry = c.pos(1) - int_max; end
                % Up-moving car approach Bottom line
                if c.vel(2)==1,  dist_to_entry = int_min - (c.pos(2)+c.dim(2)); end
                % Down-moving car approach Top line
                if c.vel(2)==-1, dist_to_entry = c.pos(2) - int_max; end
                
                % If within 5 units of entry, CHECK THE BOX
                if dist_to_entry > 0 && dist_to_entry < 5
                    
                    box_occupied = false;
                    for k=1:length(cars)
                        if k == i, continue; end
                        ck = cars(k).pos + cars(k).dim/2; % Center of car k
                        % Check if Car K is inside the intersection box
                        if ck(1) > int_min && ck(1) < int_max && ...
                           ck(2) > int_min && ck(2) < int_max
                            box_occupied = true;
                            break;
                        end
                    end
                    
                    if box_occupied
                        can_move = false; % Yield!
                    end
                end
            end
            
            % --------------------------------------------
            % EXECUTE MOVEMENT
            % --------------------------------------------
            if can_move
                c.pos = c.pos + (c.vel * speed * dt);
                set(c.h, 'Position', [c.pos, c.dim]);
            end
            
            % Cleanup if off screen
            cx = c.pos(1); cy = c.pos(2);
            if cx < -10 || cx > map_size+10 || cy < -10 || cy > map_size+10
                delete(c.h);   
                cars(i) = [];  
            else
                cars(i) = c;   
            end
        end
        
        drawnow;
        pause(dt);
    end
end