function [p,fig] = preview_webcam()

v = videoinput("winvideo", 1, "MJPG_1024x576");
v.ReturnedColorspace = "grayscale";
v.ROIPosition = [0 0 512 512];

fig = figure();
ax = axes(fig); 
 
im = image(ax,zeros(512,512,'uint8')); 
axis(ax,'image');
preview(v,im)