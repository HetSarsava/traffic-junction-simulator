function LHT_JustInTime_Traffic()
    % 1. Setup Figure
    hFig = figure('Color',[0.15 0.15 0.15], 'Name', 'Just-In-Time Logic');
    axis equal off; hold on;
    
    % --- UI SLIDER ---
    hSlider = uicontrol('Style', 'slider', 'Min', 0.2, 'Max', 3.0, 'Value', 0.8, ...
                        'Position', [150 20 300 20]);
    hLabel = uicontrol('Style', 'text', 'Position', [150 45 300 20], ...
                       'String', 'Spawn Interval: 0.8s', ...
                       'BackgroundColor', [0.15 0.15 0.15], 'ForegroundColor', 'w', ...
                       'FontSize', 10);
                        
    % --- 2. DEFINE THE JUNCTION ---
    map_size = 100;
    road_width = 16;
    center = map_size / 2;
    active_dirs = [true, true, true, true]; 
    
    Junction = struct();
    Junction.center = center;
    Junction.width = road_width;
    Junction.lane_offset = road_width / 4;
    Junction.active = active_dirs; 
    half_w = road_width / 2;
    % Bounds: [x_min, x_max, y_min, y_max]
    Junction.bounds = [center - half_w, center + half_w, center - half_w, center + half_w];
    
    xlim([0 map_size]); ylim([0 map_size]);
    draw_smart_junction(Junction, map_size);

    % --- 3. Simulation Settings ---
    % Note: cars struct is simpler now. It doesn't need pivot/radius at spawn.
    cars = struct('h', {}, 'hPivot', {}, 'pos', {}, 'angle', {}, 'intention', {}, 'state', {}, ...
                  'pivot', {}, 'radius', {}, 'start_theta', {}, 'turn_dir', {}, ...
                  'angle_covered', {}, 'speed', {}); 
    
    car_w = 4; car_l = 6;
    base_speed = 25;
    dt = 0.04;
    spawn_timer = 0;
    
    % --- 4. Main Loop ---
    while ishandle(hFig)
        spawn_timer = spawn_timer + dt;
        current_interval = get(hSlider, 'Value');
        set(hLabel, 'String', sprintf('Spawn Interval: %.2fs', current_interval));
        
        % --- A. Dumb Spawner (Only Intention, No Math) ---
        if spawn_timer > current_interval
            spawn_timer = 0; 
            
            % 1. Pick a Start Location
            valid_spawns = [];
            if Junction.active(3), valid_spawns(end+1) = 1; end % S
            if Junction.active(1), valid_spawns(end+1) = 2; end % N
            if Junction.active(4), valid_spawns(end+1) = 3; end % W
            if Junction.active(2), valid_spawns(end+1) = 4; end % E
            
            if ~isempty(valid_spawns)
                spawn_idx = randi(length(valid_spawns));
                spawn_dir = valid_spawns(spawn_idx);
                
                switch spawn_dir
                    case 1, start_pos=[center-Junction.lane_offset, -6]; angle=pi/2; col=[0.3 0.5 1];
                    case 2, start_pos=[center+Junction.lane_offset, map_size+6]; angle=-pi/2; col=[1 0.3 0.3];
                    case 3, start_pos=[-6, center+Junction.lane_offset]; angle=0; col=[0.3 0.9 0.3];
                    case 4, start_pos=[map_size+6, center-Junction.lane_offset]; angle=pi; col=[0.9 0.9 0.3];
                end
                
                % 2. Pick an Intention (0=Straight, 1=Right, 2=Left)
                r = rand; 
                if r < 0.4, intention = 0; 
                elseif r < 0.7, intention = 1; 
                else, intention = 2; 
                end

                % 3. Check Clearance
                spawn_clear = true;
                for k=1:length(cars)
                    if norm(cars(k).pos - start_pos) < 12, spawn_clear = false; break; end
                end
                
                % 4. Spawn (Notice: Pivot/Radius are empty!)
                if spawn_clear
                    hGroup = create_complex_car(start_pos, angle, col, car_w, car_l);
                    hP = plot(0, 0, 'o', 'MarkerSize', 5, 'MarkerEdgeColor', 'r', 'MarkerFaceColor', 'r', 'Visible', 'off');
                              
                    new_car = struct('h', hGroup, 'hPivot', hP, 'pos', start_pos, 'angle', angle, ...
                                     'intention', intention, 'state', 0, ...
                                     'pivot', [0,0], 'radius', 0, 'start_theta', 0, 'turn_dir', 0, ...
                                     'angle_covered', 0, 'speed', base_speed);
                    cars(end+1) = new_car;
                end
            end
        end
        
        % --- B. Movement Loop ---
        for i = length(cars):-1:1
            c = cars(i);
            
            % Collision Check (Standard)
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
                
                % --- STATE 0: APPROACHING (The "Trigger" Check) ---
                if c.state == 0
                    % Move straight
                    c.pos = c.pos + [cos(c.angle), sin(c.angle)] * c.speed * dt;
                    
                    % BOUNDARY CHECK: Have we entered the Junction Box?
                    % We check if the car's position is inside the Junction bounds
                    inside_x = c.pos(1) > Junction.bounds(1) && c.pos(1) < Junction.bounds(2);
                    inside_y = c.pos(2) > Junction.bounds(3) && c.pos(2) < Junction.bounds(4);
                    
                    if inside_x && inside_y
                        % --- JUST-IN-TIME CALCULATION ---
                        % The car has just breached the perimeter. Calculate geometry NOW.
                        
                        if c.intention == 0 % Straight
                            c.state = 2; % Skip turning state, go to Exit state
                        else
                            % Calculate Pivot and Radius based on where we are and what we want
                            [c.pivot, c.radius, c.turn_dir] = calculate_turn_geometry(c, Junction);
                            
                            c.state = 1; % Enter Turning State
                            c.start_theta = atan2(c.pos(2)-c.pivot(2), c.pos(1)-c.pivot(1));
                            c.angle_covered = 0;
                            
                            % Visuals
                            set(c.hPivot, 'XData', c.pivot(1), 'YData', c.pivot(2), 'Visible', 'on');
                        end
                    end
                    
                % --- STATE 1: TURNING (The Execution) ---
                elseif c.state == 1
                    c.angle_covered = c.angle_covered + (c.speed / c.radius) * dt;
                    curr_theta = c.start_theta + (c.angle_covered * c.turn_dir);
                    c.pos = c.pivot + c.radius * [cos(curr_theta), sin(curr_theta)];
                    
                    if c.turn_dir == 1, c.angle = curr_theta + pi/2; 
                    else, c.angle = curr_theta - pi/2; end
                    
                    % Blink Dot
                    if mod(floor(c.angle_covered * 12), 2) == 0
                         set(c.hPivot, 'MarkerFaceColor', 'r');
                    else
                         set(c.hPivot, 'MarkerFaceColor', 'none');
                    end

                    if c.angle_covered >= (pi/2 - 0.05)
                        c.state = 2;
                        c.angle = round(c.angle / (pi/2)) * (pi/2);
                        set(c.hPivot, 'Visible', 'off');
                    end
                    
                % --- STATE 2: EXITING ---
                elseif c.state == 2
                    c.pos = c.pos + [cos(c.angle), sin(c.angle)] * c.speed * dt;
                end
                
                % Update Graphics
                M = makehgtform('translate', [c.pos(1) c.pos(2) 0], 'zrotate', c.angle);
                set(c.h, 'Matrix', M);
            end
            
            % Cleanup
            if c.pos(1)<-10 || c.pos(1)>map_size+10 || c.pos(2)<-10 || c.pos(2)>map_size+10
                delete(c.h); delete(c.hPivot); cars(i) = [];
            else
                cars(i) = c;
            end
        end
        drawnow; pause(dt);
    end
end

% --- NEW FUNCTION: JUST-IN-TIME CALCULATOR ---
function [pivot, radius, turn_dir] = calculate_turn_geometry(c, Junction)
    % This function runs ONLY when the car hits the junction line.
    % It figures out the geometry based on the car's current angle.
    
    pivot = [0,0]; radius = 0; turn_dir = 0;
    
    % Determine incoming direction based on angle (approximate)
    % N->S (-pi/2), S->N (pi/2), E->W (pi), W->E (0)
    
    coming_from = '';
    if abs(c.angle - pi/2) < 0.1, coming_from = 'South';
    elseif abs(c.angle + pi/2) < 0.1, coming_from = 'North';
    elseif abs(abs(c.angle) - pi) < 0.1, coming_from = 'East';
    else, coming_from = 'West';
    end
    
    % Get Junction Bounds
    b = Junction.bounds; % [x_min, x_max, y_min, y_max]
    
    r_short = (Junction.width/2) - Junction.lane_offset;
    r_long  = (Junction.width/2) + Junction.lane_offset;
    
    if c.intention == 1 % RIGHT TURN (Long)
        radius = r_long;
        turn_dir = -1; % Clockwise
        if strcmp(coming_from, 'South'), pivot = [b(2), b(3)]; % Bottom-Right Corner
        elseif strcmp(coming_from, 'North'), pivot = [b(1), b(4)]; % Top-Left Corner
        elseif strcmp(coming_from, 'West'), pivot = [b(1), b(3)]; % Bottom-Left Corner
        elseif strcmp(coming_from, 'East'), pivot = [b(2), b(4)]; % Top-Right Corner
        end
        
    elseif c.intention == 2 % LEFT TURN (Short)
        radius = r_short;
        turn_dir = 1; % Counter-Clockwise
        if strcmp(coming_from, 'South'), pivot = [b(1), b(3)]; % Bottom-Left Corner
        elseif strcmp(coming_from, 'North'), pivot = [b(2), b(4)]; % Top-Right Corner
        elseif strcmp(coming_from, 'West'), pivot = [b(1), b(4)]; % Top-Left Corner
        elseif strcmp(coming_from, 'East'), pivot = [b(2), b(3)]; % Bottom-Right Corner
        end
    end
end

% --- DRAWING & HELPER FUNCTIONS (Standard) ---
function draw_smart_junction(J, map_size)
    x_min = J.bounds(1); x_max = J.bounds(2);
    y_min = J.bounds(3); y_max = J.bounds(4);
    fill([x_min, x_max, x_max, x_min], [y_min, y_min, y_max, y_max], [0.25 0.25 0.25], 'EdgeColor', 'y', 'LineStyle', '--');
    if J.active(1), fill([x_min, x_max, x_max, x_min], [y_max, y_max, map_size, map_size], [0.3 0.3 0.3], 'EdgeColor', 'none'); plot([J.center, J.center], [y_max, map_size], 'w--'); end
    if J.active(2), fill([x_max, map_size, map_size, x_max], [y_min, y_min, y_max, y_max], [0.3 0.3 0.3], 'EdgeColor', 'none'); plot([x_max, map_size], [J.center, J.center], 'w--'); end
    if J.active(3), fill([x_min, x_max, x_max, x_min], [0, 0, y_min, y_min], [0.3 0.3 0.3], 'EdgeColor', 'none'); plot([J.center, J.center], [0, y_min], 'w--'); end
    if J.active(4), fill([0, x_min, x_min, 0], [y_min, y_min, y_max, y_max], [0.3 0.3 0.3], 'EdgeColor', 'none'); plot([0, x_min], [J.center, J.center], 'w--'); end
end
function hGroup = create_complex_car(pos, angle, color, w, l)
    hGroup = hgtransform;
    fill([-l/2, l/2, l/2, -l/2], [-w/2, -w/2, w/2, w/2], color, 'EdgeColor', 'k', 'Parent', hGroup);
    fill([-l*0.5/2, l*0.5/2, l*0.5/2, -l*0.5/2], [-w*0.8/2, -w*0.8/2, w*0.8/2, w*0.8/2], [0.1 0.1 0.1], 'EdgeColor', 'none', 'Parent', hGroup);
    fill([l*0.5/2, l*0.5/2+l*0.15, l*0.5/2+l*0.15, l*0.5/2], [-w*0.7/2, -w*0.7/2, w*0.7/2, w*0.7/2], [0.6 0.8 1], 'EdgeColor', 'none', 'Parent', hGroup);
    fill([l/2-l*0.1, l/2, l/2, l/2-l*0.1], [w/2-w*0.2, w/2-w*0.2, w/2, w/2], [1 1 0], 'EdgeColor', 'none', 'Parent', hGroup);
    fill([l/2-l*0.1, l/2, l/2, l/2-l*0.1], [-w/2, -w/2, -w/2+w*0.2, -w/2+w*0.2], [1 1 0], 'EdgeColor', 'none', 'Parent', hGroup);
    set(hGroup, 'Matrix', makehgtform('translate', [pos(1) pos(2) 0], 'zrotate', angle));
end
function [x, y] = get_hitbox_coords(pos, w, l, angle)
    bx = [-l/2, l/2, l/2, -l/2]; by = [-w/2, -w/2, w/2, w/2];
    x = (bx*cos(angle) - by*sin(angle)) + pos(1); y = (bx*sin(angle) + by*cos(angle)) + pos(2);
end