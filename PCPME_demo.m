clc; clear; close all;
n=40;
tic
video_path=strcat('beam_vibration_2line_space_',num2str(n),'.avi');


%% ========== 1. 读取视频 ==========
v = VideoReader(video_path);

frames = {};
k = 1;
while hasFrame(v)
    frame = readFrame(v);
    frame = rgb2gray(frame);
    frames{k} = double(frame);
    k = k + 1;
end

numFrames = length(frames);
[H, W] = size(frames{1});

%% ========== 2. 选择测点 ==========
figure;
imshow(uint8(frames{1}));
title('Click a measurement point');
[x0, y0] = ginput(1);
x0 = round(x0);
y0 = round(y0);
hold on;
plot(x0, y0, 'ro');

% x0 = 355;
% y0 = 227;
%% ========== 3. 选择方向 ==========
choice = menu('Select direction', 'Horizontal (x)', 'Vertical (y)');

if choice == 1
    dir = 'x';
else
    dir = 'y';
end

%% ========== 4. 提取ROI ==========
win = 80;  % 窗口大小（可调）

x_range = max(1, x0-win):min(W, x0+win);
y_range = max(1, y0-win):min(H, y0+win);

%% ========== 5. 估计载波频率 fc ==========
% 用第一帧估计
I0 = frames{1}(y_range, x_range);

if dir == 'x'
    profile = mean(I0, 1); % 沿y平均
else
    profile = mean(I0, 2)'; % 沿x平均
end

% FFT找主频
N = length(profile);
F = abs(fft(profile - mean(profile)));
F(1) = 0; % 去掉直流

[~, idx] = max(F(1:floor(N/2)));
fc = (idx-1)/N;  % 归一化频率

fprintf('Estimated carrier frequency fc = %.4f\n', fc);

%% ========== 6. PCPME 主循环 ==========
Z = zeros(1, numFrames);

for t = 1:numFrames

    I = frames{t}(y_range, x_range);

    if dir == 'x'
        profile = mean(I, 1);
        x = 0:length(profile)-1;
    else
        profile = mean(I, 2)';
        x = 0:length(profile)-1;
    end

    % 去均值（重要）
    profile = profile - mean(profile);

    % 复指数投影（核心）
    Z(t) = sum(profile .* exp(-1i * 2*pi*fc * x));

end

%% ========== 7. 相位解算 ==========
phase = unwrap(angle(Z));

% 位移恢复
dx = phase / (2*pi*fc);

% 去初值
dx = dx - dx(1);

t=toc;
%% ========== 8. 绘图 ==========
figure;
plot(dx, 'LineWidth', 1.5);
xlabel('Frame');
ylabel('Displacement (pixel)');
title('PCPME Displacement');

% save data_40 dx phase fc n x0 y0 t