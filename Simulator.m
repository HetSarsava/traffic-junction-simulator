figure('Color',[0 0 0]);
hold on;
axis equal off;
xlim([0 20]);
ylim([0 20]);

% --- 1. Setup "+" Intersection ---
road_width = 4;
map_size = 20;
center = map_size / 2;

% Calculate boundaries for the intersection box
% The "Danger Zone" is where the roads overlap
int_start = center - (road_width/2); % 10 - 2 = 8
int_end   = center + (road_width/2); % 10 + 2 = 12

% Draw Vertical Road
rectangle('Position', [int_start, 0, road_width, map_size], ...
          'FaceColor', [0.1 0.1 0.1], 'EdgeColor', 'none');

% Draw Horizontal Road
rectangle('Position', [0, int_start, map_size, road_width], ...
          'FaceColor', [0.1 0.1 0.1], 'EdgeColor', 'none');

% --- 2. Setup Cars ---
% Dimensions
car_w = 0.7 * road_width; 
car_l = 2 * car_w;        

% Car 1 (Blue) - Starting at Bottom (Vertical)
c1_x = center - (car_w/2); 
c1_y = 0; 
hCar1 = rectangle('Position', [c1_x, c1_y, car_w, car_l], ...
                  'FaceColor', 'b', 'EdgeColor', 'none');

% Car 2 (Red) - Starting at Left (Horizontal)
% Note: We swap Width and Length for horizontal orientation!
c2_x = 0;
c2_y = center - (car_w/2);
hCar2 = rectangle('Position', [c2_x, c2_y, car_l, car_w], ...
                  'FaceColor', 'r', 'EdgeColor', 'none');

% --- 3. Simulation Logic ---
velocity = 5; 
dt = 0.05;

% Define the stopping point for Car 1
% It should stop a little bit before the intersection starts (int_start)
stop_line = int_start - car_l - 1; 

% Loop until both cars are off screen
while (c1_y < map_size) || (c2_x < map_size)
    
    % --- Logic for Red Car (Left) ---
    % The Red car has the "Right of Way", so it never stops.
    c2_x = c2_x + (velocity * dt);
    
    % --- Logic for Blue Car (Bottom) ---
    % We need to decide: Should the Blue car move?
    
    % Condition A: Is the blue car at the stop line?
    at_stop_line = (c1_y >= stop_line) && (c1_y < int_start);
    
    % Condition B: Has the red car cleared the intersection?
    % (Red car position > Intersection End + safety margin)
    red_car_clear = c2_x > (int_end + 1);
    
    if at_stop_line && ~red_car_clear
        % DO NOTHING (Wait). 
        % We do not increase c1_y here.
    else
        % Move normally
        c1_y = c1_y + (velocity * dt);
    end
    
    % --- Update Graphics ---
    hCar1.Position = [c1_x, c1_y, car_w, car_l];
    hCar2.Position = [c2_x, c2_y, car_l, car_w]; % Remember horizontal dims
    
    drawnow;
    pause(dt);
end
hold off;