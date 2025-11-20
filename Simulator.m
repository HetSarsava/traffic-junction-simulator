function LHT_TankTurnTraffic()
    % 1. Setup Figure and Map
    hFig = figure('Color',[0.2 0.2 0.2], 'Name', 'Left-Hand Traffic (LHT) Simulation');
    axis equal off;
    hold on;
    
    % --- Map Constants ---
    map_size = 100;
    road_width = 16;       
    lane_offset = road_width / 4; % Distance from center to lane middle
    center = map_size / 2;
    
    xlim([0 map_size]);
    ylim([0 map_size]);
    
    % --- Draw Roads ---
    fill([center-road_width/2, center+road_width/2, center+road_width/2, center-road_width/2], ...
         [0, 0, map_size, map_size], [0.3 0.3 0.3], 'EdgeColor', 'none');
    fill([0, map_size, map_size, 0], ...
         [center-road_width/2, center-road_width/2, center+road_width/2, center+road_width/2], ...
         [0.3 0.3 0.3], 'EdgeColor', 'none');

    % --- Visual Guides for LHT ---
    plot(center, center, 'w+', 'MarkerSize', 10);
    
    % Draw Lane Centers (The paths cars MUST follow)
    % Vertical Roads: Left is valid
    % Upbound (North): Left of center line -> X = Center - Offset
    plot([center-lane_offset center-lane_offset], [0 map_size], 'w:', 'Color', [0.6 0.6 0.6]);
    % Downbound (South): Left of center line -> X = Center + Offset
    plot([center+lane_offset center+lane_offset], [0 map_size], 'w:', 'Color', [0.6 0.6 0.6]);
    
    % Horizontal Roads: Left is valid
    % Rightbound (East): Left of center line -> Y = Center + Offset (Top Lane)
    plot([0 map_size], [center+lane_offset center+lane_offset], 'w:', 'Color', [0.6 0.6 0.6]);
    % Leftbound (West): Left of center line -> Y = Center - Offset (Bottom Lane)
    plot([0 map_size], [center-lane_offset center-lane_offset], 'w:', 'Color', [0.6 0.6 0.6]);
    
    % --- 2. Simulation Settings ---
    cars = struct('h', {}, 'pos', {}, 'angle', {}, 'type', {}, 'state', {}, ...
                  'turn_point', {}, 'target_angle', {}, 'turn_dir', {}, 'speed', {}); 
    
    car_w = 4; 
    car_l = 6;
    travel_speed = 25;
    rotation_speed = pi * 1.5; 
    dt = 0.04;
    
    spawn_timer = 0;
    spawn_interval = 1.0; 
    
    fprintf('Simulation: Left-Hand Traffic Rules Active.\n');
    
    % --- 3. Main Loop ---
    while ishandle(hFig)
        spawn_timer = spawn_timer + dt;
        
        if spawn_timer > spawn_interval
            spawn_timer = 0; 
            spawn_interval = 0.8 + rand; 
            
            % 1=From South (Going Up), 2=From North (Going Down)
            % 3=From West (Going Right), 4=From East (Going Left)
            spawn_dir = randi(4);
            
            % Movement: 40% Straight, 30% Right, 30% Left
            r = rand;
            if r < 0.4, m_type = 0;      % Straight
            elseif r < 0.7, m_type = 1;  % Right Turn
            else, m_type = 2;            % Left Turn
            end
            
            % --- DEFINE SPAWNS (LHT RULES) ---
            switch spawn_dir
                case 1 % From Bottom (Going North) -> Must be on LEFT side (x < center)
                    start_pos = [center - lane_offset, -6];
                    angle = pi/2; 
                    col = [0.4 0.6 1]; % Blue
                case 2 % From Top (Going South) -> Must be on LEFT side (x > center)
                    start_pos = [center + lane_offset, map_size+6];
                    angle = -pi/2; 
                    col = [1 0.4 0.4]; % Red
                case 3 % From Left (Going East) -> Must be on LEFT side (y > center / Top Lane)
                    start_pos = [-6, center + lane_offset];
                    angle = 0; 
                    col = [0.4 1 0.4]; % Green
                case 4 % From Right (Going West) -> Must be on LEFT side (y < center / Bottom Lane)
                    start_pos = [map_size+6, center - lane_offset];
                    angle = pi; 
                    col = [1 1 0.4]; % Yellow
            end
            
            % --- CALCULATE TURN LOGIC ---
            turn_point = [0,0];
            target_angle = angle;
            turn_dir = 0;
            
            if m_type == 1 % Right Turn
                target_angle = angle - pi/2;
                turn_dir = -1;
                
                % LHT Right Turn: This is the "Long Turn" (Crosses traffic)
                % We intersect the current lane with the target lane
                if spawn_dir==1 % North -> East (Top Lane)
                    turn_point=[center-lane_offset, center+lane_offset]; 
                end
                if spawn_dir==2 % South -> West (Bottom Lane)
                    turn_point=[center+lane_offset, center-lane_offset]; 
                end
                if spawn_dir==3 % East -> South (Right Lane)
                    turn_point=[center+lane_offset, center+lane_offset]; 
                end
                if spawn_dir==4 % West -> North (Left Lane)
                    turn_point=[center-lane_offset, center-lane_offset]; 
                end
                
            elseif m_type == 2 % Left Turn
                target_angle = angle + pi/2;
                turn_dir = 1;
                
                % LHT Left Turn: This is the "Short Turn" (Stays in near corner)
                if spawn_dir==1 % North -> West (Bottom Lane)
                    turn_point=[center-lane_offset, center-lane_offset]; 
                end
                if spawn_dir==2 % South -> East (Top Lane)
                    turn_point=[center+lane_offset, center+lane_offset]; 
                end
                if spawn_dir==3 % East -> North (Left Lane)
                    turn_point=[center-lane_offset, center+lane_offset]; 
                end
                if spawn_dir==4 % West -> South (Right Lane)
                    turn_point=[center+lane_offset, center-lane_offset]; 
                end
            end
            
            % Create Graphic
            [px, py] = get_car_coords(start_pos, car_w, car_l, angle);
            hNew = patch(px, py, col, 'EdgeColor', 'k', 'LineWidth', 1.5);
            
            new_car.h = hNew;
            new_car.pos = start_pos;
            new_car.angle = angle;
            new_car.type = m_type;
            new_car.state = 0; 
            new_car.turn_point = turn_point;
            new_car.target_angle = target_angle;
            new_car.turn_dir = turn_dir;
            new_car.speed = travel_speed;
            
            cars(end+1) = new_car;
        end
        
        % --- B. Movement Loop ---
        for i = length(cars):-1:1
            c = cars(i);
            
            % STATE 0: APPROACHING
            if c.state == 0
                if c.type == 0 % Straight
                    c.pos(1) = c.pos(1) + cos(c.angle) * c.speed * dt;
                    c.pos(2) = c.pos(2) + sin(c.angle) * c.speed * dt;
                else
                    % Check distance to Turn Point
                    dist = norm(c.pos - c.turn_point);
                    if dist < (c.speed * dt * 1.5)
                        c.pos = c.turn_point; % SNAP
                        c.state = 1; % ROTATE
                    else
                        c.pos(1) = c.pos(1) + cos(c.angle) * c.speed * dt;
                        c.pos(2) = c.pos(2) + sin(c.angle) * c.speed * dt;
                    end
                end
                
            % STATE 1: ROTATING
            elseif c.state == 1
                c.angle = c.angle + (rotation_speed * dt * c.turn_dir);
                diff = abs(angdiff(c.angle, c.target_angle));
                if diff < 0.1
                    c.angle = c.target_angle; 
                    c.state = 2; 
                end
                
            % STATE 2: EXITING
            elseif c.state == 2
                c.pos(1) = c.pos(1) + cos(c.angle) * c.speed * dt;
                c.pos(2) = c.pos(2) + sin(c.angle) * c.speed * dt;
            end
            
            % Update Graphics
            [px, py] = get_car_coords(c.pos, car_w, car_l, c.angle);
            set(c.h, 'XData', px, 'YData', py);
            
            % Cleanup
            if c.pos(1) < -10 || c.pos(1) > map_size+10 || c.pos(2) < -10 || c.pos(2) > map_size+10
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

function [x, y] = get_car_coords(pos, w, l, angle)
    bx = [-l/2, l/2, l/2, -l/2];
    by = [-w/2, -w/2, w/2, w/2];
    Rx = bx * cos(angle) - by * sin(angle);
    Ry = bx * sin(angle) + by * cos(angle);
    x = Rx + pos(1);
    y = Ry + pos(2);
end

function d = angdiff(a, b)
    d = a - b;
    d = mod(d + pi, 2*pi) - pi;
end