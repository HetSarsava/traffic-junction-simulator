function LHT_Proximity_Traffic_Entities()
    % 1. Setup Figure and Map
    hFig = figure('Color',[0.2 0.2 0.2], 'Name', 'Traffic Simulation: Real Entities');
    axis equal off;
    hold on;
    
    % --- UI SLIDER ---
    hSlider = uicontrol('Style', 'slider', 'Min', 0.2, 'Max', 3.0, 'Value', 1.0, ...
                        'Position', [150 20 300 20]);
    hLabel = uicontrol('Style', 'text', 'Position', [150 45 300 20], ...
                       'String', 'Spawn Interval: 1.0s', ...
                       'BackgroundColor', [0.2 0.2 0.2], 'ForegroundColor', 'w', ...
                       'FontSize', 10);
                        
    % --- Map Constants ---
    map_size = 100;
    road_width = 16;        
    lane_offset = road_width / 4; 
    center = map_size / 2;
    int_min = center - road_width/2;
    int_max = center + road_width/2;
    
    xlim([0 map_size]); ylim([0 map_size]);
    
    % --- Draw Roads ---
    fill([int_min, int_max, int_max, int_min], [0, 0, map_size, map_size], [0.3 0.3 0.3], 'EdgeColor', 'none');
    fill([0, map_size, map_size, 0], [int_min, int_min, int_max, int_max], [0.3 0.3 0.3], 'EdgeColor', 'none');

    % --- Visual Guides ---
    % Straight Lines
    plot([center-lane_offset center-lane_offset], [0 map_size], 'w:', 'LineWidth',1, 'Color',[0.5 0.5 0.5]);
    plot([center+lane_offset center+lane_offset], [0 map_size], 'w:', 'LineWidth',1, 'Color',[0.5 0.5 0.5]);
    plot([0 map_size], [center+lane_offset center+lane_offset], 'w:', 'LineWidth',1, 'Color',[0.5 0.5 0.5]);
    plot([0 map_size], [center-lane_offset center-lane_offset], 'w:', 'LineWidth',1, 'Color',[0.5 0.5 0.5]);
    
    % Curves
    r_short = (road_width/2) - lane_offset; 
    r_long  = (road_width/2) + lane_offset;
    draw_arc([int_min, int_min], r_short, 0, pi/2, 'w:');      
    draw_arc([int_max, int_min], r_short, pi/2, pi, 'w:');     
    draw_arc([int_max, int_max], r_short, pi, 3*pi/2, 'w:');   
    draw_arc([int_min, int_max], r_short, 3*pi/2, 2*pi, 'w:');
    draw_arc([int_max, int_min], r_long, pi/2, pi, 'w:');      
    draw_arc([int_max, int_max], r_long, pi, 3*pi/2, 'w:');    
    draw_arc([int_min, int_max], r_long, 3*pi/2, 2*pi, 'w:'); 
    draw_arc([int_min, int_min], r_long, 0, pi/2, 'w:');       
    
    % --- 2. Simulation Settings ---
    cars = struct('h', {}, 'pos', {}, 'angle', {}, 'type', {}, 'state', {}, ...
                  'pivot', {}, 'radius', {}, 'start_theta', {}, 'turn_dir', {}, ...
                  'angle_covered', {}, 'speed', {}); 
    
    car_w = 4; car_l = 6;
    base_speed = 25;
    dt = 0.04;
    spawn_timer = 0;
    
    % --- 3. Main Loop ---
    while ishandle(hFig)
        spawn_timer = spawn_timer + dt;
        current_interval = get(hSlider, 'Value');
        set(hLabel, 'String', sprintf('Spawn Interval: %.2fs', current_interval));
        
        % --- A. Spawner ---
        if spawn_timer > current_interval
            spawn_timer = 0; 
            spawn_dir = randi(4); 
            r = rand; if r < 0.4, m_type = 0; elseif r < 0.7, m_type = 1; else, m_type = 2; end
            
            pivot = [0,0]; radius = 0; turn_dir = 0; 
            switch spawn_dir
                case 1, start_pos=[center-lane_offset, -6]; angle=pi/2; col=[0.2 0.4 0.9]; % Blue
                case 2, start_pos=[center+lane_offset, map_size+6]; angle=-pi/2; col=[0.9 0.2 0.2]; % Red
                case 3, start_pos=[-6, center+lane_offset]; angle=0; col=[0.2 0.8 0.2]; % Green
                case 4, start_pos=[map_size+6, center-lane_offset]; angle=pi; col=[0.9 0.9 0.2]; % Yellow
            end
            
            % Check clearance (Math Logic unchanged)
            spawn_clear = true;
            for k=1:length(cars)
                if norm(cars(k).pos - start_pos) < 10, spawn_clear = false; break; end
            end
            
            if spawn_clear
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
                
                % --- NEW VISUALIZATION: Create Entity Group ---
                % Instead of a single patch, we create a transform group containing multiple parts
                hGroup = create_complex_car(start_pos, angle, col, car_w, car_l);
                
                new_car = struct('h', hGroup, 'pos', start_pos, 'angle', angle, ...
                                 'type', m_type, 'state', 0, 'pivot', pivot, ...
                                 'radius', radius, 'start_theta', 0, 'turn_dir', turn_dir, ...
                                 'angle_covered', 0, 'speed', base_speed);
                cars(end+1) = new_car;
            end
        end
        
        % --- B. Movement Loop ---
        for i = length(cars):-1:1
            c = cars(i);
            
            % --- PRECISE HITBOX LOGIC (UNCHANGED) ---
            % We keep the math logic exactly as it was, using a helper to calculate
            % the invisible bounding box for collision detection.
            look_ahead = 3.0; 
            
            future_pos = c.pos + [cos(c.angle), sin(c.angle)] * look_ahead;
            
            % Get Invisible Hitbox (Future)
            [fx, fy] = get_hitbox_coords(future_pos, car_w, car_l, c.angle);
            
            collision_detected = false;
            
            % Check against every other car's CURRENT body
            for j = 1:length(cars)
                if i == j, continue; end
                other = cars(j);
                
                if norm(c.pos - other.pos) > 15, continue; end
                
                % Get 'Other' car invisible hitbox
                [ox, oy] = get_hitbox_coords(other.pos, car_w, car_l, other.angle);
                
                in = inpolygon(fx, fy, ox, oy);
                if any(in) 
                    collision_detected = true; break;
                end
                
                in2 = inpolygon(ox, oy, fx, fy);
                if any(in2)
                    collision_detected = true; break;
                end
            end
            
            % --- EXECUTE MOVE ---
            if ~collision_detected
                % Perform Movement (Rail Logic - UNCHANGED)
                if c.state == 0
                    c.pos = c.pos + [cos(c.angle), sin(c.angle)] * c.speed * dt;
                    if c.type > 0
                        dist = norm(c.pos - c.pivot);
                        if abs(dist - c.radius) < 1.5 && ...
                           c.pos(1)>int_min && c.pos(1)<int_max && c.pos(2)>int_min && c.pos(2)<int_max
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
                
                % --- NEW UPDATE LOGIC: Matrix Transform ---
                % Instead of redrawing vertices, we just move the Entity Group
                M = makehgtform('translate', [c.pos(1) c.pos(2) 0], 'zrotate', c.angle);
                set(c.h, 'Matrix', M);
            end
            
            % Cleanup
            if c.pos(1)<-10 || c.pos(1)>map_size+10 || c.pos(2)<-10 || c.pos(2)>map_size+10
                delete(c.h); % Deletes the whole group
                cars(i) = [];
            else
                cars(i) = c;
            end
        end
        drawnow; pause(dt);
    end
end

% --- VISUAL HELPER: Creates the "Real Entity" ---
function hGroup = create_complex_car(pos, angle, color, w, l)
    % Create a transform group that acts as the container for the car
    hGroup = hgtransform;
    
    % Define the car parts RELATIVE to (0,0) - Local Coordinates
    
    % 1. Main Chassis (The painted body)
    fill([-l/2, l/2, l/2, -l/2], [-w/2, -w/2, w/2, w/2], color, ...
        'EdgeColor', 'k', 'Parent', hGroup);
    
    % 2. Roof/Cabin (Darker rectangle in the middle)
    rl = l * 0.5; rw = w * 0.8;
    fill([-rl/2, rl/2, rl/2, -rl/2], [-rw/2, -rw/2, rw/2, rw/2], [0.1 0.1 0.1], ...
        'EdgeColor', 'none', 'Parent', hGroup);
        
    % 3. Windshield (Light blue rect slightly offset forward)
    wl = l * 0.15; ww = w * 0.7;
    fill([rl/2, rl/2+wl, rl/2+wl, rl/2], [-ww/2, -ww/2, ww/2, ww/2], [0.6 0.8 1], ...
        'EdgeColor', 'none', 'Parent', hGroup);
        
    % 4. Headlights (Yellow circles/rects at front)
    hl = l * 0.1; hw = w * 0.2;
    % Left Headlight
    fill([l/2-hl, l/2, l/2, l/2-hl], [w/2-hw, w/2-hw, w/2, w/2], [1 1 0], ...
        'EdgeColor', 'none', 'Parent', hGroup);
    % Right Headlight
    fill([l/2-hl, l/2, l/2, l/2-hl], [-w/2, -w/2, -w/2+hw, -w/2+hw], [1 1 0], ...
        'EdgeColor', 'none', 'Parent', hGroup);

    % Apply Initial Position/Rotation
    M = makehgtform('translate', [pos(1) pos(2) 0], 'zrotate', angle);
    set(hGroup, 'Matrix', M);
end

% --- MATH HELPER: Calculates Invisible Hitbox ---
function [x, y] = get_hitbox_coords(pos, w, l, angle)
    % This is the exact math from your previous get_car_coords function
    % We use this for collision detection, but NOT for drawing.
    bx = [-l/2, l/2, l/2, -l/2]; by = [-w/2, -w/2, w/2, w/2];
    Rx = bx*cos(angle) - by*sin(angle); Ry = bx*sin(angle) + by*cos(angle);
    x = Rx + pos(1); y = Ry + pos(2);
end

function draw_arc(center, radius, s, e, style)
    t = linspace(s, e, 20); plot(center(1)+radius*cos(t), center(2)+radius*sin(t), style, 'Color', [0.6 0.6 0.6]);
end