% junction_leftlane_final.m
% Final corrected version: Cars ALWAYS drive in THEIR LEFT LANE (inner lane)
% Cars choose LEFT, STRAIGHT, or RIGHT, but remain in their left lane before/through/after.
% Works for all 4 approaches without entering oncoming lanes.

clear; close all; clc;
rng(2025);

%% ====== PARAMETERS ======
dt = 0.05;
Tsim = 60;
tvec = 0:dt:Tsim;

spot = 100;            % spawn/exit distance
lane_w = 3.5;
half_lane = lane_w/2;

veh.L = 4.8; 
veh.W = 1.9;

vmin_kmph = 45; vmax_kmph = 90; vcap_kmph = 100;
vmin = vmin_kmph*1000/3600;
vmax = vmax_kmph*1000/3600;
vcap = vcap_kmph*1000/3600;

a_max = 2.5; 
a_min = -6.0;

safe_dist = 12;

spawn_cooldown = 3.0;
spawn_extra_mean = 2.0;

% destination probabilities
p_left = 0.25; 
p_straight = 0.50; 
p_right = 0.25;

draw_traces = true;
trace_len = round(4/dt);

%% ====== APPROACH DEFINITIONS ======
% Index:
% 1 = W->E   heading +x
% 2 = E->W   heading -x
% 3 = S->N   heading +y
% 4 = N->S   heading -y

approach(1).heading = [1,0];   approach(1).spawn = [-spot, 0];
approach(2).heading = [-1,0];  approach(2).spawn = [ spot, 0];
approach(3).heading = [0,1];   approach(3).spawn = [0, -spot];
approach(4).heading = [0,-1];  approach(4).spawn = [0,  spot];

% LEFT-lane offsets — ALWAYS inner lane towards centerline
% ✔ Corrected offsets
approach(1).left_offset = [0, +half_lane];   % W->E, lane above centerline
approach(2).left_offset = [0, -half_lane];   % E->W, lane below centerline
approach(3).left_offset = [+half_lane, 0];   % S->N, lane right of centerline
approach(4).left_offset = [+half_lane, 0];   % N->S, lane right of centerline

%% ====== PATH LIBRARY (per approach x dest) ======
path_samples = 600;

paths = cell(4,3);
for a=1:4
    for d=1:3
        [pts,hdgs,slen] = build_leftlane_path(a,d,spot,path_samples,approach);
        paths{a,d}.pts = pts;
        paths{a,d}.hdgs = hdgs;
        paths{a,d}.slen = slen;
    end
end

%% ====== SPAWN SCHEDULE ======
next_spawn_time = zeros(4,1);
for a=1:4
    next_spawn_time(a) = 0.2*rand;
end

%% ====== CAR STORAGE ======
cars = struct('id',{},'approach',{},'dest',{},'pos',{},'hdg',{},'vel',{},...
    'vel_cmd',{},'path_pts',{},'path_hdgs',{},'path_s',{},'s_idx',{},...
    'state',{},'trace',{},'trace_idx',{});

next_car_id = 1;

%% ====== VISUALIZATION SETUP ======
figure('Color',[0.12 0.12 0.12],'Position',[120 80 900 900]);
axis equal; hold on;
ax_lim = 1.08*[-spot spot -spot spot];
axis(ax_lim);
set(gca,'Color',[0.06 0.06 0.07],'XColor',[1 1 1]*0.85,'YColor',[1 1 1]*0.85);
title('Cars keep THEIR LEFT LANE (Final Version)','Color','w');

% draw road lanes
rectangle('Position',[-spot, -lane_w, 2*spot, lane_w], 'FaceColor',0.95*[1 1 1]);
rectangle('Position',[-spot, 0,      2*spot, lane_w], 'FaceColor',0.95*[1 1 1]);
rectangle('Position',[-lane_w, -spot, lane_w, 2*spot], 'FaceColor',0.95*[1 1 1]);
rectangle('Position',[0,      -spot, lane_w, 2*spot], 'FaceColor',0.95*[1 1 1]);
plot([-spot,spot],[0,0],':','Color',[0.7 0.7 0.7]);
plot([0,0],[-spot,spot],':','Color',[0.7 0.7 0.7]);

%% ====== MAIN SIMULATION LOOP ======
for k=1:length(tvec)
    now = tvec(k);

    %% --- SPAWN CARS ---
    for a=1:4
        if now >= next_spawn_time(a)

            % choose destination
            r = rand;
            if r < p_left
                d = 1;
            elseif r < p_left + p_straight
                d = 2;
            else
                d = 3;
            end

            % random speed
            vk = randi([vmin_kmph, vmax_kmph]);
            v0 = min(vk*1000/3600, vcap);

            % spawn at first point on that lane/path
            pos = paths{a,d}.pts(1,:);
            hdg = paths{a,d}.hdgs(1);

            cars(end+1).id = next_car_id;
            cars(end).approach = a;
            cars(end).dest = d;
            cars(end).pos = pos;
            cars(end).hdg = hdg;
            cars(end).vel = v0;
            cars(end).vel_cmd = v0;
            cars(end).path_pts = paths{a,d}.pts;
            cars(end).path_hdgs = paths{a,d}.hdgs;
            cars(end).path_s = path_arc_length_param(paths{a,d}.pts);
            cars(end).s_idx = 1;
            cars(end).state = "approaching";
            cars(end).trace = nan(trace_len,2);
            cars(end).trace_idx = 1;

            next_car_id = next_car_id + 1;

            % next spawn time
            extra = -spawn_extra_mean*log(rand+eps);
            next_spawn_time(a) = now + spawn_cooldown + extra;
        end
    end

    %% --- UPDATE CARS ---
    N = numel(cars);
    for i=1:N
        if isempty(cars(i).id), continue; end

        pts = cars(i).path_pts;
        sarr = cars(i).path_s;
        idx  = cars(i).s_idx;

        v_des = cars(i).vel_cmd;

        % leader detection on the SAME approach & SAME dest path
        si = sarr(idx);
        leader_s = inf;
        leader_idx = -1;

        for j=1:N
            if i==j || isempty(cars(j).id), continue; end
            if cars(j).approach ~= cars(i).approach, continue; end
            if cars(j).dest ~= cars(i).dest, continue; end

            sj = sarr(cars(j).s_idx);
            if sj > si && sj < leader_s
                leader_s = sj;
                leader_idx = j;
            end
        end

        % safe distance
        if leader_idx ~= -1
            gap = leader_s - si - veh.L;
            if gap < safe_dist
                v_des = min(v_des, max(0.5, cars(leader_idx).vel * (gap/safe_dist)));
            end
        end

        % accel limits
        dv = v_des - cars(i).vel;
        if dv>0
            dv_lim = min(dv, a_max*dt);
        else
            dv_lim = max(dv, a_min*dt);
        end
        cars(i).vel = cars(i).vel + dv_lim;

        % step along path
        s_next = si + cars(i).vel*dt;
        idx_next = find(sarr >= s_next,1);
        if isempty(idx_next), idx_next = numel(sarr); end

        cars(i).s_idx = idx_next;
        cars(i).pos   = pts(idx_next,:);
        cars(i).hdg   = cars(i).path_hdgs(idx_next);

        % record trace
        cars(i).trace(cars(i).trace_idx,:) = cars(i).pos;
        cars(i).trace_idx = mod(cars(i).trace_idx, trace_len) + 1;

        % remove if far beyond exit
        if idx_next >= numel(sarr)
            if norm(cars(i).pos) > spot + 10
                cars(i).id = [];
            end
        end
    end

    % purge removed cars
    alive = ~cellfun(@isempty, {cars.id});
    cars = cars(alive);

    %% --- DRAW FRAME ---
    cla;

    rectangle('Position',[-spot, -lane_w, 2*spot, lane_w], 'FaceColor',0.95*[1 1 1]);
    rectangle('Position',[-spot, 0,      2*spot, lane_w], 'FaceColor',0.95*[1 1 1]);
    rectangle('Position',[-lane_w, -spot, lane_w, 2*spot], 'FaceColor',0.95*[1 1 1]);
    rectangle('Position',[0,      -spot, lane_w, 2*spot], 'FaceColor',0.95*[1 1 1]);

    plot([-spot,spot],[0,0],':','Color',[0.7 0.7 0.7]);
    plot([0,0],[-spot,spot],':','Color',[0.7 0.7 0.7]);

    for i=1:numel(cars)
        % draw car rectangle
        R = [cos(cars(i).hdg), -sin(cars(i).hdg); 
             sin(cars(i).hdg),  cos(cars(i).hdg)];
        half = [veh.L/2, veh.W/2];
        corners_local = [ half; -half(1),half(2); -half; half(1),-half(2)];
        corners = (R * corners_local')' + cars(i).pos;

        patch(corners(:,1), corners(:,2), [0 0.45 0.85], 'EdgeColor', 'k');

        % speed label
        text(cars(i).pos(1)+1, cars(i).pos(2)+1, ...
            sprintf('%dkm/h',round(cars(i).vel*3.6)), ...
            'Color','w','FontSize',8);

        % trace
        if draw_traces
            tr = cars(i).trace;
            valid = ~any(isnan(tr),2);
            if any(valid)
                plot(tr(valid,1), tr(valid,2), 'Color',[0 0.45 0.85]*0.6);
            end
        end
    end

    axis(ax_lim);
    title(sprintf('t = %.1f s | vehicles: %d', now, numel(cars)), 'Color','w');
    drawnow limitrate;

end

fprintf("Simulation complete.\n");


%% ====== SUPPORT FUNCTIONS ======

function [pts,hdgs,slen] = build_leftlane_path(a,d,spot,samps,A)
% Build left-lane-based straight/left/right turn path for approach a.
% a: approach index 1..4
% d: 1=LEFT turn, 2=STRAIGHT, 3=RIGHT
% A: struct of approaches containing heading, spawn, left_offset

    spawnA = A(a).spawn;
    hdA    = A(a).heading;
    offA   = A(a).left_offset;

    % determine exit approach for the turn
    if d==2
        b = opposite(a);
    elseif d==1
        b = left(a);
    else
        b = right(a);
    end

    spawnB = A(b).spawn;
    hdB    = A(b).heading;
    offB   = A(b).left_offset;

    % approach segment
    p_start = spawnA + offA;
    approach_stop = 10;
    p_midA = offA + (-approach_stop)*hdA;

    n1 = round(0.35*samps);
    seg1 = [ linspace(p_start(1), p_midA(1), n1)', ...
             linspace(p_start(2), p_midA(2), n1)' ];

    % central waypoint computed by line intersection of left lanes
    M = [hdA(:), -hdB(:)];
    rhs = (offB(:) - offA(:));
    if abs(det(M)) < 1e-6
        p_center = [0,0];
    else
        sol = M\rhs;
        p_center = offA + sol(1)*hdA;
    end

    n2 = round(0.30*samps);
    seg2 = [ linspace(p_midA(1), p_center(1), n2)', ...
             linspace(p_midA(2), p_center(2), n2)' ];

    % exit segment
    p_exit = -spawnB + offB;
    n3 = round(0.35*samps);
    seg3 = [ linspace(p_center(1), p_exit(1), n3)', ...
             linspace(p_center(2), p_exit(2), n3)' ];

    pts = [seg1; seg2; seg3];

    dpts = diff(pts);
    hdgs = atan2([dpts(:,2); dpts(end,2)], [dpts(:,1); dpts(end,1)]);
    slen = sum(sqrt(sum(diff(pts).^2,2)));
end

function b = opposite(a)
    if a==1, b=2; elseif a==2, b=1;
    elseif a==3, b=4; else, b=3; end
end
function b = left(a)
    if a==1, b=3; elseif a==2, b=4;
    elseif a==3, b=2; else, b=1; end
end
function b = right(a)
    if a==1, b=4; elseif a==2, b=3;
    elseif a==3, b=1; else, b=2; end
end

function s = path_arc_length_param(pts)
    dp = diff(pts);
    seglen = sqrt(sum(dp.^2,2));
    s = [0; cumsum(seglen)];
end
