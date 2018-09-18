% ensemble model 
% ����ģ�͵Ļ�ģ�͸����ǹ̶���
% �ж����ݿ��Ƿ�������Ư�ƣ�1)�����������Ư�ƣ�����������Ư�Ƶ����ݿ���뼯��ģ�ͣ��������ģ�͸������������������滻���ϵĻ�ģ�ͣ������ڷ����µ����ݿ�
%                           2)���δ��������Ư�ƣ����滻��Ϊ���Ƶ����ݿ鹹���ķ�����
% ����ģ�͵ķ����ģ�����ż�����Ư�Ƶ����ݿ���������Ӷ����ӣ���������ÿ�����ݼ�����ʱ���ģ�͵ĸ�������ﵽ�����������磬������ݼ�ֻ����2�θ���Ư��
%                           ���������ݿ�����ڹ�������ģ�͵��������ݿ鶼��������Ư�ƣ�����ô��ģ�͵���Ŀֻ����3��������10
% ����ģ�͹�����ʽ
% ��ĳ�����ݿ�����������Ϊͬһ���ʱ���޷���������������ʱ�����ݿ�Ԥ���µ����ݿ�Ϊͬһ���
% �����������ݿ�֮���������������Ϊ����������Ȩֵ
% �޸�����2018.04.02
function STSC
addpath('libsvm-3.22');
% parameters setting
%D:/Data/ExperimentDataForWSDM2018/Snippets/oBTMchunk-all-cp100-700-unorder/tmp-50/
%D:/Data/ExperimentDataForWSDM2018/News.title/oBTMchunk-all-cp100-700-unorder/tmp-50/
%D:/Data/ExperimentDataForWSDM2018/Tweets/EoBTM-chunk30000/tmp-1000/
data_dir = 'D:/Data/ExperimentDataForWSDM2018/News.title/oBTMchunk-all-cp100-700-unorder/tmp-50/';
all_chunk_num = 652;
base_classifier_num = 10;
label_num = 7;
niu = 1-0.5/label_num;

% global variabale
global base_classifier;
global preCount;
global preerror;

%initial
base_classifier = struct;
Accuracy = zeros(all_chunk_num,1);
InAccuracy = zeros(all_chunk_num,1);
preError = zeros(all_chunk_num,1);
% training and predict
curr_base_classifier_inx = 0;
% curr_base_classifier_inx = base_classifier_num;
curr_accuracy = 0;
num_insts = 0;
preCount = 0;
preerror = 0;
t1=clock;
for i=1:all_chunk_num
    disp(num2str(i));
    [ label, data ] = libsvmread([data_dir num2str(i-1) '.txt']);
    label = label + 1;
    data_num = size(data,1);
    if i==all_chunk_num
        disp('11111111111');
    end
    [ accuracy, addbm1, replacebm_inx  ] = PREDICT( label, data, label_num, data_num, niu );
    curr_accuracy = accuracy + curr_accuracy;
    if i>1
        num_insts = num_insts + data_num;
        InAccuracy(i) = curr_accuracy/num_insts;
        Accuracy(i) = accuracy/data_num;
        preError(i) = (preerror)/preCount;
    else
        InAccuracy(i) = 0;
        Accuracy(i) = 0;
        preError(i) = 0;
    end   
    [ model, addbm2 ] = BUILD_ENSEMBLEMODEL( label, data );
    if (addbm1==1)&&(addbm2==1)
        if curr_base_classifier_inx < base_classifier_num
            curr_base_classifier_inx = curr_base_classifier_inx+1;
            base_classifier(curr_base_classifier_inx).model = model;
            base_classifier(curr_base_classifier_inx).data = data;
            base_classifier(curr_base_classifier_inx).label = label;
            base_classifier(curr_base_classifier_inx).timestamp = 0;
        else
            [base_model_N1, base_model_N2] = size(base_classifier);
            maxtimestamp = 0;
            for j=1:base_model_N2
                if base_classifier(j).timestamp>maxtimestamp
                    replacebm_inx = j;
                    maxtimestamp = base_classifier(j).timestamp;
                end
            end
            base_classifier(replacebm_inx).model = model;
            base_classifier(replacebm_inx).data = data;
            base_classifier(replacebm_inx).label = label;
            base_classifier(replacebm_inx).timestamp = 0;
        end
        
    end
    if (addbm1==0)&&(addbm2==1)
        base_classifier(replacebm_inx).model = model;
        base_classifier(replacebm_inx).data = data;
        base_classifier(replacebm_inx).label = label;
        base_classifier(replacebm_inx).timestamp = 0;
    end
    if isfield(base_classifier(1), 'model')
        [base_model_N1, base_model_N2] = size(base_classifier);
        for j=1:base_model_N2
            base_classifier(j).timestamp = base_classifier(j).timestamp + 1;
        end
    end    

    
end
t2=clock;
disp(num2str(etime(t2,t1)));

fid=fopen('D:/Data/ExperimentDataForWSDM2018/Snippets/oBTMchunk-all-cp100-700-unorder/Accurracy-5classifier','w');
fprintf(fid,'%6.3f\n',Accuracy);
fclose(fid);

fid=fopen('D:/Data/ExperimentDataForWSDM2018/Snippets/oBTMchunk-all-cp100-700-unorder/InAccurracy-5classifier','w');
fprintf(fid,'%6.3f\n',InAccuracy);
fclose(fid);

fid=fopen('D:/Data/ExperimentDataForWSDM2018/Snippets/oBTMchunk-all-cp100-700-unorder/preError-5classifier','w');
fprintf(fid,'%6.3f\n',preError);
fclose(fid);


end

% predict test set
% INPUT: class label, test data, label number and test data number of test set,
% OUTPUT: accuracy, if it should been added to base classifiers
function [ accuracy, addbm, min_bc_inx ] = PREDICT( test_label, test_data, test_label_num, test_data_num, niu )
addpath('libsvm-3.22');
global base_classifier;
global preCount;
global preerror;
accuracy = 0;
addbm = 0;
min_bc_inx = 0;
fadingFactor = 0.995
if ~isfield(base_classifier(1), 'model'); addbm = 1; return,end

[base_model_N1, base_model_N2] = size(base_classifier);
P2D = zeros(test_label_num, test_data_num);
Y2D = zeros (test_label_num, test_data_num);
for i=1:test_label_num
    i_idx = test_label == i;
    Y2D( i,i_idx ) = 1;    
end

% detect concept drift and calculate weights
num_cp = 0;
min_cp = 1;
W = struct;
sum_W = zeros(test_data_num,test_label_num);
num_W = zeros(test_data_num,test_label_num);
for i=1:base_model_N2
    cos_E2A = COSINE( test_data, base_classifier(i).data );
    s_W = zeros(test_data_num,test_label_num);
    for k=1:test_label_num
        k_idx = base_classifier(i).label==k;
        Ic = cos_E2A(:,k_idx);
        Ic = mean(Ic .* (size(Ic,2)/test_data_num),2);
        s_W(:,k) = Ic;        
    end
    s_W(isnan(s_W))=0;
    dist_value = sum(min(1.-s_W,[],2))/test_data_num
    if dist_value>niu
        num_cp = num_cp + 1;
    end
    if min_cp>dist_value
        min_bc_inx = i;
        min_cp = dist_value;
    end
    W(i).v = s_W;
    W(i).sv = 1-dist_value;
    sum_W = sum_W + s_W;
    s_W(s_W>0) = 1;
    num_W = num_W + s_W;
end
if num_cp == base_model_N2
   addbm = 1; 
end
num_W(num_W==0) = 1;
sum_W = sum_W./num_W;
Max_sum_W = repmat(max(sum_W,[],2),1,test_label_num);
Pre_sum_W = (sum_W==Max_sum_W);

num_P2D = zeros(test_label_num, test_data_num);
for i=1:base_model_N2
    if base_classifier(i).model.nr_class < 2
        prob_estimates = zeros(test_data_num, 1);
        prob_estimates(:,1) = 1;
    else
        [ plabel, paccuracy, prob_estimates ] = svmpredict( test_label, test_data, base_classifier(i).model,'-b 1' );
    end               
    slabel = base_classifier(i).model.Label;
    if size(slabel,1)<test_label_num
        prob_estimates(:,(size(slabel,1)+1):test_label_num) = zeros(size(prob_estimates,1),(test_label_num-size(slabel,1)));
    end
    s_Y2S = zeros(test_label_num, test_label_num);
    for k=1:test_label_num
        k_idx = slabel==k; 
        s_Y2S(k,k_idx) = 1;
    end
    s_P2D = s_Y2S * prob_estimates';
    %P2D = P2D + (s_P2D.*W(i).v').*W(i).sv;
    P2D = P2D + s_P2D.*W(i).sv;
    s_P2D(s_P2D>0) = 1;
    num_P2D = num_P2D + s_P2D;
end
num_P2D(num_P2D==0) = 1;
P2D = P2D./num_P2D;
Max_P = repmat(max(P2D),test_label_num,1);
Pre_M = (P2D==Max_P);
for i=1:test_data_num
    preCount = preCount * fadingFactor + 1;
    accuracy = accuracy + isequal(Pre_M(:,i),Y2D(:,i));
    if isequal(Pre_M(:,i),Y2D(:,i)) == 1
        preerror = preerror * fadingFactor + 0;
    else
        preerror = preerror * fadingFactor + 1;
    end
end
%accuracy = accuracy/test_data_num;
%disp(num2str(accuracy/test_data_num));

end

% build base classifier
% INPUT: class label, train data of train set, and 
% OUTPUT: classifier model, if it should been added to base classifiers
function [ model, addbm ] = BUILD_ENSEMBLEMODEL( train_label, train_data, curr_base_classifier_inx )
addpath('libsvm-3.22');
global base_classifier;

addbm = 1;
model = svmtrain( train_label, train_data, '-h 0 -t 0 -c 32 -b 1');
%if model.nr_class < 2
%    addbm = 0;
%end

end

% calculate cosine similarity
% INPUT: two matrix
% OUTPUT: cosine similarity 
function [ cos_X2Y ] = COSINE( X, Y )
cos_X2Y = (X*Y')./(sqrt(sum(X.^2,2))*(sqrt(sum(Y.^2,2)))');
end
