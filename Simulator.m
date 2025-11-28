function LHT_Junction_Object()
    % 1. Setup Figure
    hFig = figure('Color',[0.15 0.15 0.15], 'Name', 'Smart Junction Object');
    axis equal off;
    hold on;
    
    % --- UI SLIDER ---
    hSlider = uicontrol('Style', 'slider', 'Min', 0.2, 'Max', 3.0, 'Value', 0.8, ...
                        'Position', [150 20 300 20]);
    hLabel = uicontrol('Style', 'text', 'Position', [150 45 300 20], ...
                       'String', 'Spawn Interval: 0.8s', ...
                       'BackgroundColor', [0.15 0.15 0.15], 'ForegroundColor', 'w', ...
                       'FontSize', 10);
                        
    % --- 2. DEFINE THE JUNCTION OBJECT ---
    map_size = 100;
    road_width = 16;
    center = map_size / 2;
    
    % [N, E, S, W] - Set these to true/false to build different intersections
    % Example: [1 1 1 1] = 4-way, [1 1 0 1] = T-Junction
    active_dirs = [true, true, true, true]; 
    
    Junction = struct();
    Junction.center = center;
    Junction.width = road_width;
    Junction.lane_offset = road_width / 4;
    Junction.active = active_dirs; % [North, East, South, West]
    
    % Define the "Special" Crossroad Boundary (The Center Box)
    half_w = road_width / 2;
    Junction.bounds = [center - half_w, center + half_w, center - half_w, center + half_w];
    % bounds = [x_min, x_max, y_min, y_max]

    % Map Limits
    xlim([0 map_size]); ylim([0 map_size]);

    % --- 3. Draw the Map based on the Object ---
    draw_smart_junction(Junction, map_size);

    % --- 4. Simulation Settings ---
    cars = struct('h', {}, 'pos', {}, 'angle', {}, 'type', {}, 'state', {}, ...
                  'pivot', {}, 'radius', {}, 'start_theta', {}, 'turn_dir', {}, ...
                  'angle_covered', {}, 'speed', {}); 
    
    car_w = 4; car_l = 6;
    base_speed = 25;
    dt = 0.04;
    spawn_timer = 0;
    
    % --- 5. Main Loop ---
    while ishandle(hFig)
        spawn_timer = spawn_timer + dt;
        current_interval = get(hSlider, 'Value');
        set(hLabel, 'String', sprintf('Spawn Interval: %.2fs', current_interval));
        
        % --- A. Spawner (Aware of Junction Object) ---
        if spawn_timer > current_interval
            spawn_timer = 0; 
            
            % Find which starting points are valid based on Junction.active
            valid_spawns = [];
            % Map Spawner ID to Direction: 
            % 1=South(heading N), 2=North(heading S), 3=West(heading E), 4=East(heading W)
            if Junction.active(3), valid_spawns(end+1) = 1; end % Spawn at Bottom (South)
            if Junction.active(1), valid_spawns(end+1) = 2; end % Spawn at Top (North)
            if Junction.active(4), valid_spawns(end+1) = 3; end % Spawn at Left (West)
            if Junction.active(2), valid_spawns(end+1) = 4; end % Spawn at Right (East)
            
            if ~isempty(valid_spawns)
                spawn_idx = randi(length(valid_spawns));
                spawn_dir = valid_spawns(spawn_idx);
                
                % Determine turn type based on availability
                % Ideally we check if destination road exists, but for now we randomize
                r = rand; 
                if r < 0.4, m_type = 0; % Straight
                elseif r < 0.7, m_type = 1; % Right
                else, m_type = 2; % Left
                end

                pivot = [0,0]; radius = 0; turn_dir = 0; 
                
                % Define Start Pos based on direction
                switch spawn_dir
                    case 1 % From Bottom
                        start_pos=[center-Junction.lane_offset, -6]; 
                        angle=pi/2; col=[0.3 0.5 1];
                    case 2 % From Top
                        start_pos=[center+Junction.lane_offset, map_size+6]; 
                        angle=-pi/2; col=[1 0.3 0.3];
                    case 3 % From Left
                        start_pos=[-6, center+Junction.lane_offset]; 
                        angle=0; col=[0.3 0.9 0.3];
                    case 4 % From Right
                        start_pos=[map_size+6, center-Junction.lane_offset]; 
                        angle=pi; col=[0.9 0.9 0.3];
                end
                
                % Setup Turns
                r_short = (road_width/2) - Junction.lane_offset;
                r_long  = (road_width/2) + Junction.lane_offset;
                int_min = Junction.bounds(1);
                int_max = Junction.bounds(2);

                if m_type == 1 % Right Turn
                    radius = r_long;
                    if spawn_dir==1, pivot=[int_max, int_min]; turn_dir=-1;
                    elseif spawn_dir==2, pivot=[int_min, int_max]; turn_dir=-1;
                    elseif spawn_dir==3, pivot=[int_min, int_min]; turn_dir=-1;
                    elseif spawn_dir==4, pivot=[int_max, int_max]; turn_dir=-1; end
                elseif m_type == 2 % Left Turn
                    radius = r_short;
                    if spawn_dir==1, pivot=[int_min, int_min]; turn_dir=1;
                    elseif spawn_dir==2, pivot=[int_max, int_max]; turn_dir=1;
                    elseif spawn_dir==3, pivot=[int_min, int_max]; turn_dir=1;
                    elseif spawn_dir==4, pivot=[int_max, int_min]; turn_dir=1; end
                end
                
                % Check Clearance
                spawn_clear = true;
                for k=1:length(cars)
                    if norm(cars(k).pos - start_pos) < 12, spawn_clear = false; break; end
                end
                
                if spawn_clear
                    hGroup = create_complex_car(start_pos, angle, col, car_w, car_l);
                    new_car = struct('h', hGroup, 'pos', start_pos, 'angle', angle, ...
                                     'type', m_type, 'state', 0, 'pivot', pivot, ...
                                     'radius', radius, 'start_theta', 0, 'turn_dir', turn_dir, ...
                                     'angle_covered', 0, 'speed', base_speed);
                    cars(end+1) = new_car;
                end
            end
        end
        
        % --- B. Movement Loop ---
        for i = length(cars):-1:1
            c = cars(i);
            
            % Collision Logic (Unchanged)
            look_ahead = 3.5; 
            future_pos = c.pos + [cos(c.angle), sin(c.angle)] * look_ahead;
            [fx, fy] = get_hitbox_coords(future_pos, car_w, car_l, c.angle);
            
            collision_detected = false;
            for j = 1:length(cars)
                if i == j, continue; end
                other = cars(j);
                if norm(c.pos - other.pos) > 16, continue; end
                [ox, oy] = get_hitbox_coords(other.pos, car_w, car_l, other.angle);
                if any(inpolygon(fx, fy, ox, oy)) || any(inpolygon(ox, oy, fx, fy))
                    collision_detected = true; break;
                end
            end
            
            if ~collision_detected
                % Rail Logic using Junction Bounds
                int_min = Junction.bounds(1);
                int_max = Junction.bounds(2);
                
                if c.state == 0
                    c.pos = c.pos + [cos(c.angle), sin(c.angle)] * c.speed * dt;
                    if c.type > 0
                        dist = norm(c.pos - c.pivot);
                        % Check if we are inside the logical junction area
                        if abs(dist - c.radius) < 1.8 && ...
                           c.pos(1)>int_min-2 && c.pos(1)<int_max+2 && ...
                           c.pos(2)>int_min-2 && c.pos(2)<int_max+2
                           
                           c.state = 1;
                           c.start_theta = atan2(c.pos(2)-c.pivot(2), c.pos(1)-c.pivot(1));
                           c.angle_covered = 0;
                        end
                    end
                elseif c.state == 1
                    c.angle_covered = c.angle_covered + (c.speed / c.radius) * dt;
                    curr_theta = c.start_theta + (c.angle_covered * c.turn_dir);
                    c.pos = c.pivot + c.radius * [cos(curr_theta), sin(curr_theta)];
                    if c.turn_dir == 1, c.angle = curr_theta + pi/2; else, c.angle = curr_theta - pi/2; end
                    if c.angle_covered >= (pi/2 - 0.05)
                        c.state = 2;
                        c.angle = round(c.angle / (pi/2)) * (pi/2);
                    end
                elseif c.state == 2
                    c.pos = c.pos + [cos(c.angle), sin(c.angle)] * c.speed * dt;
                end
                
                % Update Graphic
                M = makehgtform('translate', [c.pos(1) c.pos(2) 0], 'zrotate', c.angle);
                set(c.h, 'Matrix', M);
            end
            
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

% --- DRAWING FUNCTIONS ---

function draw_smart_junction(J, map_size)
    % Extract boundaries
    x_min = J.bounds(1); x_max = J.bounds(2);
    y_min = J.bounds(3); y_max = J.bounds(4);
    
    % 1. Draw The "Special" Crossroad Boundary (Center Box)
    % We use a slightly different color to denote the hazard zone
    fill([x_min, x_max, x_max, x_min], [y_min, y_min, y_max, y_max], ...
         [0.25 0.25 0.25], 'EdgeColor', 'y', 'LineStyle', '--', 'LineWidth', 1);

    % 2. Draw Roads based on Active Directions
    % N=1, E=2, S=3, W=4 (Indices of active array)
    
    % North Arm (Top)
    if J.active(1)
        fill([x_min, x_max, x_max, x_min], [y_max, y_max, map_size, map_size], ...
             [0.3 0.3 0.3], 'EdgeColor', 'none');
        % Center Line
        plot([J.center, J.center], [y_max, map_size], 'w--', 'LineWidth', 1);
    end
    
    % East Arm (Right)
    if J.active(2)
        fill([x_max, map_size, map_size, x_max], [y_min, y_min, y_max, y_max], ...
             [0.3 0.3 0.3], 'EdgeColor', 'none');
        % Center Line
        plot([x_max, map_size], [J.center, J.center], 'w--', 'LineWidth', 1);
    end
    
    % South Arm (Bottom)
    if J.active(3)
        fill([x_min, x_max, x_max, x_min], [0, 0, y_min, y_min], ...
             [0.3 0.3 0.3], 'EdgeColor', 'none');
        % Center Line
        plot([J.center, J.center], [0, y_min], 'w--', 'LineWidth', 1);
    end
    
    % West Arm (Left)
    if J.active(4)
        fill([0, x_min, x_min, 0], [y_min, y_min, y_max, y_max], ...
             [0.3 0.3 0.3], 'EdgeColor', 'none');
        % Center Line
        plot([0, x_min], [J.center, J.center], 'w--', 'LineWidth', 1);
    end
    
    % 3. Draw Corner Curves (Visual cues for turns)
    % Only draw corner if BOTH adjacent roads are active
    r = 2; % Visual radius
    % Top-Right Corner (North + East)
    if J.active(1) && J.active(2)
        draw_visual_arc([x_max, y_max], r, 0, pi/2);
    end
    % Top-Left Corner (North + West)
    if J.active(1) && J.active(4)
        draw_visual_arc([x_min, y_max], r, pi/2, pi);
    end
    % Bottom-Left (South + West)
    if J.active(3) && J.active(4)
        draw_visual_arc([x_min, y_min], r, pi, 3*pi/2);
    end
    % Bottom-Right (South + East)
    if J.active(3) && J.active(2)
        draw_visual_arc([x_max, y_min], r, 3*pi/2, 2*pi);
    end
end

function draw_visual_arc(corner, r, s, e)
    t = linspace(s, e, 10);
    plot(corner(1)+r*cos(t), corner(2)+r*sin(t), 'w', 'LineWidth', 1);
end

% --- ENTITY & MATH HELPERS ---

function hGroup = create_complex_car(pos, angle, color, w, l)
    hGroup = hgtransform;
    % Chassis
    fill([-l/2, l/2, l/2, -l/2], [-w/2, -w/2, w/2, w/2], color, ...
        'EdgeColor', 'k', 'Parent', hGroup);
    % Roof
    rl = l * 0.5; rw = w * 0.8;
    fill([-rl/2, rl/2, rl/2, -rl/2], [-rw/2, -rw/2, rw/2, rw/2], [0.1 0.1 0.1], ...
        'EdgeColor', 'none', 'Parent', hGroup);
    % Windshield
    wl = l * 0.15; ww = w * 0.7;
    fill([rl/2, rl/2+wl, rl/2+wl, rl/2], [-ww/2, -ww/2, ww/2, ww/2], [0.6 0.8 1], ...
        'EdgeColor', 'none', 'Parent', hGroup);
    % Headlights
    hl = l * 0.1; hw = w * 0.2;
    fill([l/2-hl, l/2, l/2, l/2-hl], [w/2-hw, w/2-hw, w/2, w/2], [1 1 0], ...
        'EdgeColor', 'none', 'Parent', hGroup);
    fill([l/2-hl, l/2, l/2, l/2-hl], [-w/2, -w/2, -w/2+hw, -w/2+hw], [1 1 0], ...
        'EdgeColor', 'none', 'Parent', hGroup);

    M = makehgtform('translate', [pos(1) pos(2) 0], 'zrotate', angle);
    set(hGroup, 'Matrix', M);
end

function [x, y] = get_hitbox_coords(pos, w, l, angle)
    bx = [-l/2, l/2, l/2, -l/2]; by = [-w/2, -w/2, w/2, w/2];
    Rx = bx*cos(angle) - by*sin(angle); Ry = bx*sin(angle) + by*cos(angle);
    x = Rx + pos(1); y = Ry + pos(2);
end