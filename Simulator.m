figure('Color',[0 0 0]);
hold on;
axis equal off;

% --- 1. Setup Map ---
map_size = 60;
road_width = 6;
center = map_size / 2;
xlim([0 map_size]);
ylim([0 map_size]);

% Intersection Zone
int_start = center - (road_width/2);
int_end   = center + (road_width/2);

% Draw Roads
rectangle('Position', [int_start, 0, road_width, map_size], ...
          'FaceColor', [0.1 0.1 0.1], 'EdgeColor', 'none');
rectangle('Position', [0, int_start, map_size, road_width], ...
          'FaceColor', [0.1 0.1 0.1], 'EdgeColor', 'none');

% --- 2. Setup Cars ---
car_w = 0.7 * road_width;
car_l = 2 * car_w;

% Car 1 (Bottom)
c1_x = center - (car_w/2); c1_y = 0;
hCar1 = rectangle('Position', [c1_x, c1_y, car_w, car_l], ...
                  'FaceColor', 'b', 'EdgeColor', 'none');

% Car 2 (Left)
c2_x = 0; c2_y = center - (car_w/2);
hCar2 = rectangle('Position', [c2_x, c2_y, car_l, car_w], ...
                  'FaceColor', 'b', 'EdgeColor', 'none');

% --- 3. RANDOM START LOGIC ---
% We set a "Danger Delay". 
% 0.8 seconds is short enough that they WOULD crash if no one stopped,
% but long enough that one is clearly ahead of the other.
danger_delay = 0.8; 

if rand > 0.5
    % Case A: Bottom Car goes first
    start_time_1 = 0;
    start_time_2 = danger_delay;
    title('Priority: Bottom Car (Vertical)', 'Color', 'w');
else
    % Case B: Left Car goes first
    start_time_1 = danger_delay;
    start_time_2 = 0;
    title('Priority: Left Car (Horizontal)', 'Color', 'w');
end

% --- 4. Simulation Loop ---
velocity = 15;
dt = 0.05;
sim_time = 0;

% Stop Lines (Safety buffer before entering intersection)
stop_line = int_start - car_l - 1; 

while (c1_y < map_size) || (c2_x < map_size)
    sim_time = sim_time + dt;
    
    % --- COLLISION AVOIDANCE SENSORS ---
    
    % Is the car physically occupying the intersection?
    % (Position > Start AND Position < End + Safety Buffer)
    c1_in_intersection = (c1_y > int_start - 1) && (c1_y < int_end + 2);
    c2_in_intersection = (c2_x > int_start - 1) && (c2_x < int_end + 2);
    
    % --- Move Car 1 (Vertical) ---
    if sim_time > start_time_1
        % Logic: If I am at the stop line AND the other car is in the way...
        at_stop = (c1_y >= stop_line) && (c1_y < int_start);
        
        if at_stop && c2_in_intersection
            % STOP! (Do not add velocity)
        else
            c1_y = c1_y + (velocity * dt);
        end
    end
    
    % --- Move Car 2 (Horizontal) ---
    if sim_time > start_time_2
        % Logic: If I am at the stop line AND the other car is in the way...
        at_stop = (c2_x >= stop_line) && (c2_x < int_start);
        
        if at_stop && c1_in_intersection
            % STOP! (Do not add velocity)
        else
            c2_x = c2_x + (velocity * dt);
        end
    end
    
    % Update Graphics
    hCar1.Position = [c1_x, c1_y, car_w, car_l];
    hCar2.Position = [c2_x, c2_y, car_l, car_w];
    
    drawnow;
    pause(dt);
end
hold off;