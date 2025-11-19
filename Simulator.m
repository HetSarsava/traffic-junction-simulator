figure('Color',[0 0 0]);
hold on;
axis equal off;

% --- 1. Setup Static Background ---
road_W_total = 10;
road_H = 20;

% Draw Road
rectangle('Position',[0 0 road_W_total road_H], ...
          'FaceColor',[0.1 0.1 0.1], 'EdgeColor','none');

% Draw Lines
line_Left = 3;
line_Right = 7;
plot([line_Left line_Left],[0 road_H],'w','LineWidth',3);
plot([line_Right line_Right],[0 road_H],'w','LineWidth',3);

xlim([0 road_W_total]);
ylim([0 road_H]);

% --- 2. Setup Car ---
lane_width = line_Right - line_Left;
car_W = 0.7 * lane_width; 
car_L = 2 * car_W;      

lane_center = (line_Left + line_Right) / 2;
car_x = lane_center - (car_W / 2);

% Initial Y position
current_y = 0; 

% Create the Car Object
hCar = rectangle('Position', [car_x, current_y, car_W, car_L], ...
                 'FaceColor', 'b', 'EdgeColor', 'none');

% --- 3. Physics Configuration ---
velocity = 5;   % Speed: 5 units per second
dt = 0.05;      % Time step: Update every 0.05 seconds (20 frames per second)

% --- 4. Animation Loop ---
% Using 'while' gives us more control than 'for'
while current_y < road_H
    
    % Calculate new position based on speed and time
    % Distance = Velocity * Time
    current_y = current_y + (velocity * dt);
    
    % Update the car on screen
    hCar.Position = [car_x, current_y, car_W, car_L];
    
    % Update the graph
    drawnow;
    
    % Pause for the duration of the time step to maintain constant speed
    pause(dt); 
end

hold off;