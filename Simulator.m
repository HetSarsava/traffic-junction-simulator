function LHT_SmoothTraffic_Fixed()
    % 1. Setup Figure and Map
    hFig = figure('Color',[0.2 0.2 0.2], 'Name', 'LHT Smooth Traffic (Fixed)');
    axis equal off;
    hold on;
    
    % --- Map Constants ---
    map_size = 100;
    road_width = 16;       
    lane_offset = road_width / 4; 
    center = map_size / 2;
    
    % Intersection Boundaries
    int_min = center - road_width/2;
    int_max = center + road_width/2;
    
    xlim([0 map_size]);
    ylim([0 map_size]);
    
    % --- Draw Base Roads ---
    fill([int_min, int_max, int_max, int_min], ...
         [0, 0, map_size, map_size], [0.3 0.3 0.3], 'EdgeColor', 'none');
    fill([0, map_size, map_size, 0], ...
         [int_min, int_min, int_max, int_max], ...
         [0.3 0.3 0.3], 'EdgeColor', 'none');

    % --- Draw Visual Guides (Tracks) ---
    % 1. STRAIGHT LINES (Restored)
    % Vertical Left (S -> N)
    plot([center-lane_offset center-lane_offset], [0 map_size], 'w:', 'LineWidth', 1, 'Color', [0.6 0.6 0.6]);
    % Vertical Right (N -> S)
    plot([center+lane_offset center+lane_offset], [0 map_size], 'w:', 'LineWidth', 1, 'Color', [0.6 0.6 0.6]);
    % Horizontal Top (W -> E)
    plot([0 map_size], [center+lane_offset center+lane_offset], 'w:', 'LineWidth', 1, 'Color', [0.6 0.6 0.6]);
    % Horizontal Bottom (E -> W)
    plot([0 map_size], [center-lane_offset center-lane_offset], 'w:', 'LineWidth', 1, 'Color', [0.6 0.6 0.6]);

    % 2. CURVED LINES
    r_short = (road_width/2) - lane_offset; % Left Turn
    r_long  = (road_width/2) + lane_offset; % Right Turn
    
    % Draw the 4 Short Turns (Left)
    draw_arc([int_min, int_min], r_short, 0, pi/2, 'w:');     
    draw_arc([int_max, int_min], r_short, pi/2, pi, 'w:');    
    draw_arc([int_max, int_max], r_short, pi, 3*pi/2, 'w:');  
    draw_arc([int_min, int_max], r_short, 3*pi/2, 2*pi, 'w:');
    
    % Draw the 4 Long Turns (Right)
    draw_arc([int_max, int_min], r_long, pi/2, pi, 'w:');     
    draw_arc([int_max, int_max], r_long, pi, 3*pi/2, 'w:');   
    draw_arc([int_min, int_max], r_long, 3*pi/2, 2*pi, 'w:'); 
    draw_arc([int_min, int_min], r_long, 0, pi/2, 'w:');      
    
    % --- 2. Simulation Settings ---
    % state: 0=Approach, 1=InCurve, 2=Exit
    % angle_covered: Tracks progress from 0 to pi/2
    cars = struct('h', {}, 'pos', {}, 'angle', {}, 'type', {}, 'state', {}, ...
                  'pivot', {}, 'radius', {}, 'start_theta', {}, 'turn_dir', {}, ...
                  'angle_covered', {}, 'speed', {}); 
    
    car_w = 4; car_l = 6;
    speed_val = 25;
    dt = 0.04;
    spawn_timer = 0;
    spawn_interval = 1.0; 
    
    % --- 3. Main Loop ---
    while ishandle(hFig)
        spawn_timer = spawn_timer + dt;
        
        % --- A. Spawner ---
        if spawn_timer > spawn_interval
            spawn_timer = 0; 
            spawn_interval = 0.8 + rand; 
            spawn_dir = randi(4); 
            
            % 0=Straight, 1=Right(Long), 2=Left(Short)
            r = rand;
            if r < 0.4, m_type = 0; elseif r < 0.7, m_type = 1; else, m_type = 2; end
            
            pivot = [0,0]; radius = 0; turn_dir = 0; % +1 CCW, -1 CW
            
            switch spawn_dir
                case 1 % From South (Going North)
                    start_pos = [center - lane_offset, -6];
                    angle = pi/2; col = [0.4 0.6 1];
                case 2 % From North (Going South)
                    start_pos = [center + lane_offset, map_size+6];
                    angle = -pi/2; col = [1 0.4 0.4];
                case 3 % From West (Going East)
                    start_pos = [-6, center + lane_offset];
                    angle = 0; col = [0.4 1 0.4];
                case 4 % From East (Going West)
                    start_pos = [map_size+6, center - lane_offset];
                    angle = pi; col = [1 1 0.4];
            end
            
            % Define Turn Geometry based on LHT
            if m_type == 1 % Right Turn (Wide, CW or CCW depends on corner)
                radius = r_long;
                if spawn_dir==1 % S->E (Pivot is SE corner)
                    pivot = [int_max, int_min]; turn_dir = -1; % CW
                elseif spawn_dir==2 % N->W (Pivot NW corner)
                    pivot = [int_min, int_max]; turn_dir = -1; % CW
                elseif spawn_dir==3 % W->S (Pivot SW corner)
                    pivot = [int_min, int_min]; turn_dir = -1; % CW
                elseif spawn_dir==4 % E->N (Pivot NE corner)
                    pivot = [int_max, int_max]; turn_dir = -1; % CW
                end
            elseif m_type == 2 % Left Turn (Tight)
                radius = r_short;
                if spawn_dir==1 % S->W (Pivot SW corner)
                    pivot = [int_min, int_min]; turn_dir = 1; % CCW
                elseif spawn_dir==2 % N->E (Pivot NE corner)
                    pivot = [int_max, int_max]; turn_dir = 1; % CCW
                elseif spawn_dir==3 % W->N (Pivot NW corner)
                    pivot = [int_min, int_max]; turn_dir = 1; % CCW
                elseif spawn_dir==4 % E->S (Pivot SE corner)
                    pivot = [int_max, int_min]; turn_dir = 1; % CCW
                end
            end
            
            [px, py] = get_car_coords(start_pos, car_w, car_l, angle);
            hNew = patch(px, py, col, 'EdgeColor', 'k');
            
            new_car = struct('h', hNew, 'pos', start_pos, 'angle', angle, ...
                             'type', m_type, 'state', 0, 'pivot', pivot, ...
                             'radius', radius, 'start_theta', 0, 'turn_dir', turn_dir, ...
                             'angle_covered', 0, 'speed', speed_val);
            cars(end+1) = new_car;
        end
        
        % --- B. Movement Loop ---
        for i = length(cars):-1:1
            c = cars(i);
            
            % STATE 0: APPROACH
            if c.state == 0
                c.pos = c.pos + [cos(c.angle), sin(c.angle)] * c.speed * dt;
                
                % If turning, check for intersection entry
                if c.type > 0
                    dist_to_pivot = norm(c.pos - c.pivot);
                    err = abs(dist_to_pivot - c.radius);
                    
                    % If we hit the virtual "rail"
                    if err < 1.5 && ...
                       c.pos(1) > int_min && c.pos(1) < int_max && ...
                       c.pos(2) > int_min && c.pos(2) < int_max
                        
                       c.state = 1;
                       % Calculate exact angle on circle at entry
                       c.start_theta = atan2(c.pos(2)-c.pivot(2), c.pos(1)-c.pivot(1));
                       c.angle_covered = 0; % Reset counter
                    end
                end
                
            % STATE 1: SMOOTH CURVE
            elseif c.state == 1
                % 1. Calculate how much angle we change in this frame
                % w = v / r
                ang_step = (c.speed / c.radius) * dt;
                
                % 2. Accumulate total progress (always positive counter)
                c.angle_covered = c.angle_covered + ang_step;
                
                % 3. Calculate actual current theta
                current_theta = c.start_theta + (c.angle_covered * c.turn_dir);
                
                % 4. Update Position
                c.pos(1) = c.pivot(1) + c.radius * cos(current_theta);
                c.pos(2) = c.pivot(2) + c.radius * sin(current_theta);
                
                % 5. Update Heading (Tangent)
                % Tangent is perpendicular (+/- 90deg) to the radius
                if c.turn_dir == 1 % CCW
                    c.angle = current_theta + pi/2;
                else % CW
                    c.angle = current_theta - pi/2;
                end
                
                % 6. Check for Exit (Have we turned 90 degrees?)
                if c.angle_covered >= (pi/2 - 0.05)
                    c.state = 2;
                    % Snap to perfect 90-degree heading
                    c.angle = round(c.angle / (pi/2)) * (pi/2);
                end
                
            % STATE 2: EXIT
            elseif c.state == 2
                c.pos = c.pos + [cos(c.angle), sin(c.angle)] * c.speed * dt;
            end
            
            % Update GFX
            [px, py] = get_car_coords(c.pos, car_w, car_l, c.angle);
            set(c.h, 'XData', px, 'YData', py);
            
            % Cleanup
            if c.pos(1)<-10 || c.pos(1)>map_size+10 || c.pos(2)<-10 || c.pos(2)>map_size+10
                delete(c.h); cars(i) = [];
            else
                cars(i) = c;
            end
        end
        drawnow; pause(dt);
    end
end

% --- Helpers ---
function [x, y] = get_car_coords(pos, w, l, angle)
    bx = [-l/2, l/2, l/2, -l/2];
    by = [-w/2, -w/2, w/2, w/2];
    Rx = bx*cos(angle) - by*sin(angle);
    Ry = bx*sin(angle) + by*cos(angle);
    x = Rx + pos(1); y = Ry + pos(2);
end

function draw_arc(center, radius, start_ang, end_ang, style)
    t = linspace(start_ang, end_ang, 20);
    x = center(1) + radius*cos(t);
    y = center(2) + radius*sin(t);
    plot(x, y, style, 'LineWidth', 1, 'Color', [0.6 0.6 0.6]);
end