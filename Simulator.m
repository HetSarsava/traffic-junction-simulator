function TwoWayTrafficSim()
    % 1. Setup Figure and Map
    hFig = figure('Color',[0.2 0.2 0.2], 'Name', 'Two-Way Traffic Simulation');
    axis equal off;
    hold on;
    
    % --- Map Constants ---
    map_size = 100;
    road_width = 14;       
    lane_width = road_width / 2;
    center = map_size / 2;
    
    xlim([0 map_size]);
    ylim([0 map_size]);
    
    % --- Draw Roads ---
    rectangle('Position', [center - road_width/2, 0, road_width, map_size], ...
              'FaceColor', [0.4 0.4 0.4], 'EdgeColor', 'none');
    rectangle('Position', [0, center - road_width/2, map_size, road_width], ...
              'FaceColor', [0.4 0.4 0.4], 'EdgeColor', 'none');
          
    % --- Draw Dashed Center Lines ---
    plot([center center], [0 map_size], 'w--', 'LineWidth', 1);
    plot([0 map_size], [center center], 'w--', 'LineWidth', 1);
    
    % --- 2. Simulation Settings ---
    % FIX IS HERE: Added 'dim', {} so it matches the new cars we create
    cars = struct('h', {}, 'pos', {}, 'dim', {}, 'vel', {}); 
    
    car_w = 3;
    car_l = 5;
    speed = 20;
    dt = 0.05;
    
    spawn_timer = 0;
    spawn_interval = 1.5; 
    
    fprintf('Simulation started. Close the figure window to stop.\n');
    
    % --- 3. Main Loop ---
    while ishandle(hFig)
        spawn_timer = spawn_timer + dt;
        
        if spawn_timer > spawn_interval
            spawn_timer = 0; 
            spawn_interval = 0.3 + (rand * 0.5);
            
            offset = lane_width / 2;
            
            % [StartX, StartY, VelX, VelY, Color]
            cfg_Bot = {center + offset, -5,          0,  1,  'b'}; 
            cfg_Top = {center - offset, map_size+5,  0, -1,  'r'};
            cfg_Lft = {-5,              center - offset, 1,  0,  'g'};
            cfg_Rgt = {map_size+5,      center + offset, -1, 0,  'y'};
            
            options = {cfg_Bot, cfg_Top, cfg_Lft, cfg_Rgt};
            
            pick = options{randi(4)};
            
            vx = pick{3}; 
            vy = pick{4};
            col = pick{5};
            
            if vx == 0 
                w = car_w; l = car_l; 
            else            
                w = car_l; l = car_w; 
            end
            
            start_pos = [pick{1} - w/2, pick{2} - l/2];
            
            hNew = rectangle('Position', [start_pos, w, l], ...
                             'FaceColor', col, 'EdgeColor', 'k');
            
            % Create the new car struct
            new_car.h = hNew;
            new_car.pos = start_pos;
            new_car.dim = [w, l]; % This now matches the list definition
            new_car.vel = [vx, vy];
            
            cars(end+1) = new_car;
        end
        
        % B. Movement Loop
        for i = length(cars):-1:1
            c = cars(i);
            
            c.pos = c.pos + (c.vel * speed * dt);
            
            set(c.h, 'Position', [c.pos, c.dim]);
            
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