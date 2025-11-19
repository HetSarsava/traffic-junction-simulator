figure('Color',[0 0 0]);
hold on;
axis equal off;

% --- 1. Setup Road and Lines ---
road_W_total = 10;
road_H = 20;

% Draw background (The black asphalt)
rectangle('Position',[0 0 road_W_total road_H], 'FaceColor',[0.1 0.1 0.1], 'EdgeColor','none');

% Define Lane Lines
line_Left = 3;
line_Right = 7;

% Draw Lines
plot([line_Left line_Left],[0 road_H],'w','LineWidth',3);
plot([line_Right line_Right],[0 road_H],'w','LineWidth',3);

% --- 2. Create Car Object ---
% Calculate the width of the actua lane
lane_width = line_Right - line_Left; % This equals 4

% Define Car Dimensions
car_W = 0.7 * lane_width; % 0.7 * 4 = 2.8
car_L = 2 * car_W;        % 1:2 ratio = 5.6

% Center the car in the lane
lane_center = (line_Left + line_Right) / 2;

car_x = lane_center - (car_W / 2);
car_y = (road_H - car_L) / 2;

% Draw the Car
rectangle('Position', [car_x, car_y, car_W, car_L], ...
          'FaceColor', 'b', 'EdgeColor', 'none');

% Set view limits
xlim([0 road_W_total]);
ylim([0 road_H]);
hold off;