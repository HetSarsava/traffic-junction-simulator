% Simple one-way road with two white lines

figure('Color',[0 0 0]);     % Black background (road)
hold on;
axis equal off;

% Road rectangle (optional visual boundary)
rectangle('Position',[0 0 10 20], 'FaceColor',[0.1 0.1 0.1], 'EdgeColor','none');

% White lane divider lines
plot([3 3],[0 20],'w','LineWidth',3);
plot([7 7],[0 20],'w','LineWidth',3);

xlim([0 10]);
ylim([0 20]);

hold off;
