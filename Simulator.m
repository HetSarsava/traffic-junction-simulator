function LHT_Layered_Grid()
    % 1. Setup Figure
    hFig = figure('Color',[0.15 0.15 0.15], 'Name', 'LHT Layered Grid');
    axis equal off; hold on;
    
    % --- UI SLIDER ---
    hSlider = uicontrol('Style', 'slider', 'Min', 0.2, 'Max', 2.0, 'Value', 0.6, ...
                        'Position', [150 20 300 20]);
    hLabel = uicontrol('Style', 'text', 'Position', [150 45 300 20], ...
                       'String', 'Spawn Interval: 0.6s', ...
                       'BackgroundColor', [0.15 0.15 0.15], 'ForegroundColor', 'w', ...
                       'FontSize', 10);
                        
    % --- 2. DEFINE MAP (2x2 Grid) ---
    map_size = 200;
    road_width = 16;
    
    centers = [60, 60; 140, 60; 60, 140; 140, 140];
    
    Junctions = [];
    for k = 1:4
        J = struct();
        J.center = centers(k, :);
        J.width = road_width;
        J.lane_offset = road_width / 4;
        J.active = [true, true, true, true]; 
        
        half_w = road_width / 2;
        cx = J.center(1); cy = J.center(2);
        J.bounds = [cx - half_w, cx + half_w, cy - half_w, cy + half_w];
        
        Junctions = [Junctions, J];
    end
    
    xlim([0 map_size]); ylim([0 map_size]);
    
    % --- 3. DRAWING (LAYERED) ---
    % FIX: We split drawing into two passes to prevent overlap issues
    
    % PASS 1: Draw All Roads (Bottom Layer)
    for k = 1:length(Junctions)
        draw_road_arms(Junctions(k), map_size);
    end
    
    % PASS 2: Draw All Hollow Centers (Top Layer)
    for k = 1:length(Junctions)
        draw_hollow_box(Junctions(k));
    end

    % --- 4. Simulation Settings ---
    cars = struct('h', {}, 'hPivot', {}, 'pos', {}, 'angle', {}, ...
                  'intention', {}, 'intention_idx', {}, ... 
                  'state', {}, 'pivot', {}, 'radius', {}, 'start_theta', {}, ...
                  'turn_dir', {}, 'angle_covered', {}, 'speed', {}); 
    
    car_w = 4; car_l = 6;
    base_speed = 30;
    dt = 0.04;
    spawn_timer = 0;
    
    % --- 5. Main Loop ---
    while ishandle(hFig)
        spawn_timer = spawn_timer + dt;
        current_interval = get(hSlider, 'Value');
        set(hLabel, 'String', sprintf('Spawn Interval: %.2fs', current_interval));
        
        % --- A. Spawner ---
        if spawn_timer > current_interval
            spawn_timer = 0; 
            off = road_width/4;
            
            % Spawns [x, y, angle]
            spawns = [
                60-off, -6, pi/2;          
                140-off, -6, pi/2;         
                60+off, map_size+6, -pi/2; 
                140+off, map_size+6, -pi/2;
                -6, 60+off, 0;             
                -6, 140+off, 0;            
                map_size+6, 60-off, pi;    
                map_size+6, 140-off, pi    
            ];
            
            idx = randi(8);
            start_pos = spawns(idx, 1:2);
            angle = spawns(idx, 3);
            
            intention_list = randi([0 2], 1, 10);
            col = [rand rand rand]; 

            spawn_clear = true;
            for k=1:length(cars)
                if norm(cars(k).pos - start_pos) < 15, spawn_clear = false; break; end
            end
            
            if spawn_clear
                hGroup = create_complex_car(start_pos, angle, col, car_w, car_l);
                hP = plot(0, 0, 'o', 'MarkerSize', 4, 'MarkerEdgeColor', 'r', 'MarkerFaceColor', 'r', 'Visible', 'off');
                          
                new_car = struct('h', hGroup, 'hPivot', hP, 'pos', start_pos, 'angle', angle, ...
                                 'intention', intention_list, 'intention_idx', 1, ...
                                 'state', 0, 'pivot', [0,0], 'radius', 0, ...
                                 'start_theta', 0, 'turn_dir', 0, 'angle_covered', 0, 'speed', base_speed);
                cars(end+1) = new_car;
            end
        end
        
        % --- B. Movement Loop ---
        for i = length(cars):-1:1
            c = cars(i);
            
            % Collision Check
            look_ahead = 4.0; 
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
                
                % --- STATE 0: APPROACHING ---
                if c.state == 0
                    c.pos = c.pos + [cos(c.angle), sin(c.angle)] * c.speed * dt;
                    
                    for k = 1:length(Junctions)
                        J = Junctions(k);
                        if c.pos(1) > J.bounds(1) && c.pos(1) < J.bounds(2) && ...
                           c.pos(2) > J.bounds(3) && c.pos(2) < J.bounds(4)
                            
                            if c.intention_idx <= length(c.intention)
                                current_action = c.intention(c.intention_idx);
                            else
                                current_action = 0; 
                            end
                            c.intention_idx = c.intention_idx + 1;
                            
                            if current_action == 0 
                                c.state = 2; 
                            else
                                [c.pivot, c.radius, c.turn_dir] = calculate_robust_lht(c, J, current_action);
                                c.state = 1;
                                c.start_theta = atan2(c.pos(2)-c.pivot(2), c.pos(1)-c.pivot(1));
                                c.angle_covered = 0;
                                set(c.hPivot, 'XData', c.pivot(1), 'YData', c.pivot(2), 'Visible', 'on');
                            end
                            break; 
                        end
                    end
                    
                % --- STATE 1: TURNING ---
                elseif c.state == 1
                    c.angle_covered = c.angle_covered + (c.speed / c.radius) * dt;
                    curr_theta = c.start_theta + (c.angle_covered * c.turn_dir);
                    c.pos = c.pivot + c.radius * [cos(curr_theta), sin(curr_theta)];
                    
                    if c.turn_dir == 1, c.angle = curr_theta + pi/2; 
                    else, c.angle = curr_theta - pi/2; end
                    
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
                    
                    in_any_junction = false;
                    for k = 1:length(Junctions)
                        J = Junctions(k);
                        if c.pos(1) > J.bounds(1) && c.pos(1) < J.bounds(2) && ...
                           c.pos(2) > J.bounds(3) && c.pos(2) < J.bounds(4)
                           in_any_junction = true;
                           break;
                        end
                    end
                    if ~in_any_junction
                        c.state = 0; 
                    end
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

% --- LAYERED DRAWING FUNCTIONS ---

function draw_road_arms(J, map_size)
    % Only draws the grey road extensions
    x_min = J.bounds(1); x_max = J.bounds(2);
    y_min = J.bounds(3); y_max = J.bounds(4);
    
    if J.active(1), fill([x_min, x_max, x_max, x_min], [y_max, y_max, map_size, map_size], [0.3 0.3 0.3], 'EdgeColor', 'none'); plot([J.center(1), J.center(1)], [y_max, map_size], 'w--'); end
    if J.active(2), fill([x_max, map_size, map_size, x_max], [y_min, y_min, y_max, y_max], [0.3 0.3 0.3], 'EdgeColor', 'none'); plot([x_max, map_size], [J.center(2), J.center(2)], 'w--'); end
    if J.active(3), fill([x_min, x_max, x_max, x_min], [0, 0, y_min, y_min], [0.3 0.3 0.3], 'EdgeColor', 'none'); plot([J.center(1), J.center(1)], [0, y_min], 'w--'); end
    if J.active(4), fill([0, x_min, x_min, 0], [y_min, y_min, y_max, y_max], [0.3 0.3 0.3], 'EdgeColor', 'none'); plot([0, x_min], [J.center(2), J.center(2)], 'w--'); end
end

function draw_hollow_box(J)
    % Only draws the hollow center box
    x_min = J.bounds(1); x_max = J.bounds(2);
    y_min = J.bounds(3); y_max = J.bounds(4);
    
    % Draw box with background color fill and white edge
    fill([x_min, x_max, x_max, x_min], [y_min, y_min, y_max, y_max], ...
         [0.15 0.15 0.15], 'EdgeColor', 'w', 'LineWidth', 1.5);
end

% --- CALCULATOR & HELPERS ---
function [pivot, radius, turn_dir] = calculate_robust_lht(c, J, action)
    pivot = [0,0]; radius = 0; turn_dir = 0;
    b = J.bounds;
    TL = [b(1), b(4)]; TR = [b(2), b(4)];
    BL = [b(1), b(3)]; BR = [b(2), b(3)];
    
    dx = c.pos(1) - J.center(1);
    dy = c.pos(2) - J.center(2);
    r_short = (J.width/2) - J.lane_offset;
    r_long  = (J.width/2) + J.lane_offset;
    
    if action == 2 % LEFT (Short)
        radius = r_short; turn_dir = 1; 
        if dx < 0 && dy < 0, pivot = BL;
        elseif dx < 0 && dy > 0, pivot = TL;
        elseif dx > 0 && dy > 0, pivot = TR;
        elseif dx > 0 && dy < 0, pivot = BR;
        end
    elseif action == 1 % RIGHT (Long)
        radius = r_long; turn_dir = -1;
        if dx < 0 && dy < 0, pivot = BR;
        elseif dx < 0 && dy > 0, pivot = BL;
        elseif dx > 0 && dy > 0, pivot = TL;
        elseif dx > 0 && dy < 0, pivot = TR;
        end
    end
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