package com.birdkingdom.service;

import com.birdkingdom.dto.CreatePostRequest;
import com.birdkingdom.dto.ForumPostDTO;
import com.birdkingdom.dto.PostCommentDTO;
import com.birdkingdom.entity.*;
import com.birdkingdom.repository.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class ForumService {

    private final ForumPostRepository postRepository;
    private final PostImageRepository imageRepository;
    private final PostCommentRepository commentRepository;
    private final PostLikeRepository likeRepository;
    private final PostFavoriteRepository favoriteRepository;
    private final CommentLikeRepository commentLikeRepository;
    private final UserFollowRepository followRepository;
    private final UserRepository userRepository;

    public ForumService(ForumPostRepository postRepository, PostImageRepository imageRepository,
                        PostCommentRepository commentRepository, PostLikeRepository likeRepository,
                        PostFavoriteRepository favoriteRepository, CommentLikeRepository commentLikeRepository,
                        UserFollowRepository followRepository, UserRepository userRepository) {
        this.postRepository = postRepository;
        this.imageRepository = imageRepository;
        this.commentRepository = commentRepository;
        this.likeRepository = likeRepository;
        this.favoriteRepository = favoriteRepository;
        this.commentLikeRepository = commentLikeRepository;
        this.followRepository = followRepository;
        this.userRepository = userRepository;
    }
    
    /**
     * 获取帖子列表
     */
    public Page<ForumPostDTO> getPosts(int page, int size, Long currentUserId) {
        Pageable pageable = PageRequest.of(page, size);
        Page<ForumPost> posts = postRepository.findAllByOrderByCreatedAtDesc(pageable);
        return posts.map(post -> convertToDTO(post, currentUserId));
    }
    
    /**
     * 获取用户的帖子
     */
    public Page<ForumPostDTO> getUserPosts(Long userId, int page, int size, Long currentUserId) {
        Pageable pageable = PageRequest.of(page, size);
        Page<ForumPost> posts = postRepository.findByAuthorIdOrderByCreatedAtDesc(userId, pageable);
        return posts.map(post -> convertToDTO(post, currentUserId));
    }
    
    /**
     * 获取帖子详情
     */
    public ForumPostDTO getPostDetail(Long postId, Long currentUserId) {
        ForumPost post = postRepository.findById(postId)
            .orElseThrow(() -> new RuntimeException("帖子不存在"));
        
        // 增加浏览量
        post.setViewCount(post.getViewCount() + 1);
        postRepository.save(post);
        
        return convertToDTO(post, currentUserId);
    }
    
    /**
     * 创建帖子
     */
    @Transactional
    public ForumPostDTO createPost(Long userId, CreatePostRequest request) {
        User author = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("用户不存在"));
        
        ForumPost post = new ForumPost();
        post.setAuthor(author);
        post.setContent(request.getContent());
        post.setPostType(request.getPostType() != null ? request.getPostType() : "NORMAL");
        post.setLatitude(request.getLatitude());
        post.setLongitude(request.getLongitude());
        post.setLocationName(request.getLocationName());
        
        // 寻鸟专用字段
        if ("FIND_BIRD".equals(request.getPostType())) {
            post.setBirdName(request.getBirdName());
            post.setBirdSpecies(request.getBirdSpecies());
            post.setLostLocation(request.getLostLocation());
            post.setContactPhone(request.getContactPhone());
            post.setReward(request.getReward());
        }
        
        postRepository.save(post);
        
        // 保存图片
        if (request.getImages() != null && !request.getImages().isEmpty()) {
            for (int i = 0; i < request.getImages().size(); i++) {
                PostImage image = new PostImage();
                image.setPost(post);
                image.setImageUrl(request.getImages().get(i));
                image.setSortOrder(i);
                imageRepository.save(image);
            }
        }
        
        return convertToDTO(post, userId);
    }
    
    /**
     * 删除帖子
     */
    @Transactional
    public void deletePost(Long postId, Long userId) {
        ForumPost post = postRepository.findById(postId)
            .orElseThrow(() -> new RuntimeException("帖子不存在"));
        
        if (!post.getAuthor().getId().equals(userId)) {
            throw new RuntimeException("无权删除此帖子");
        }
        
        postRepository.delete(post);
    }
    
    /**
     * 点赞/取消点赞
     */
    @Transactional
    public boolean toggleLike(Long postId, Long userId) {
        ForumPost post = postRepository.findById(postId)
            .orElseThrow(() -> new RuntimeException("帖子不存在"));
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("用户不存在"));
        
        if (likeRepository.existsByPostIdAndUserId(postId, userId)) {
            likeRepository.deleteByPostIdAndUserId(postId, userId);
            post.setLikeCount(Math.max(0, post.getLikeCount() - 1));
            postRepository.save(post);
            return false;
        } else {
            PostLike like = new PostLike();
            like.setPost(post);
            like.setUser(user);
            likeRepository.save(like);
            post.setLikeCount(post.getLikeCount() + 1);
            postRepository.save(post);
            return true;
        }
    }
    
    /**
     * 收藏/取消收藏
     */
    @Transactional
    public boolean toggleFavorite(Long postId, Long userId) {
        ForumPost post = postRepository.findById(postId)
            .orElseThrow(() -> new RuntimeException("帖子不存在"));
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("用户不存在"));
        
        if (favoriteRepository.existsByPostIdAndUserId(postId, userId)) {
            favoriteRepository.deleteByPostIdAndUserId(postId, userId);
            return false;
        } else {
            PostFavorite favorite = new PostFavorite();
            favorite.setPost(post);
            favorite.setUser(user);
            favoriteRepository.save(favorite);
            return true;
        }
    }
    
    /**
     * 获取用户收藏的帖子
     */
    public Page<ForumPostDTO> getFavorites(Long userId, int page, int size) {
        Pageable pageable = PageRequest.of(page, size);
        Page<PostFavorite> favorites = favoriteRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable);
        return favorites.map(fav -> convertToDTO(fav.getPost(), userId));
    }
    
    /**
     * 添加评论
     */
    @Transactional
    public PostCommentDTO addComment(Long postId, Long userId, String content, Long parentId) {
        ForumPost post = postRepository.findById(postId)
            .orElseThrow(() -> new RuntimeException("帖子不存在"));
        User author = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("用户不存在"));
        
        PostComment comment = new PostComment();
        comment.setPost(post);
        comment.setAuthor(author);
        comment.setContent(content);
        
        if (parentId != null) {
            PostComment parent = commentRepository.findById(parentId)
                .orElseThrow(() -> new RuntimeException("父评论不存在"));
            comment.setParent(parent);
        }
        
        commentRepository.save(comment);
        
        // 更新帖子评论数
        post.setCommentCount(post.getCommentCount() + 1);
        postRepository.save(post);
        
        return convertCommentToDTO(comment, userId);
    }
    
    /**
     * 获取帖子评论
     */
    public Page<PostCommentDTO> getComments(Long postId, int page, int size, Long currentUserId) {
        Pageable pageable = PageRequest.of(page, size);
        Page<PostComment> comments = commentRepository.findByPostIdAndParentIsNullOrderByCreatedAtAsc(postId, pageable);
        return comments.map(comment -> {
            PostCommentDTO dto = convertCommentToDTO(comment, currentUserId);
            // 加载回复
            List<PostComment> replies = commentRepository.findByParentIdOrderByCreatedAtAsc(comment.getId());
            dto.setReplies(replies.stream()
                .map(reply -> convertCommentToDTO(reply, currentUserId))
                .collect(Collectors.toList()));
            return dto;
        });
    }
    
    /**
     * 评论点赞/取消点赞
     */
    @Transactional
    public boolean toggleCommentLike(Long commentId, Long userId) {
        PostComment comment = commentRepository.findById(commentId)
            .orElseThrow(() -> new RuntimeException("评论不存在"));
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("用户不存在"));
        
        if (commentLikeRepository.existsByCommentIdAndUserId(commentId, userId)) {
            commentLikeRepository.deleteByCommentIdAndUserId(commentId, userId);
            comment.setLikeCount(Math.max(0, comment.getLikeCount() - 1));
            commentRepository.save(comment);
            return false;
        } else {
            CommentLike like = new CommentLike();
            like.setComment(comment);
            like.setUser(user);
            commentLikeRepository.save(like);
            comment.setLikeCount(comment.getLikeCount() + 1);
            commentRepository.save(comment);
            return true;
        }
    }
    
    /**
     * 转换帖子为DTO
     */
    private ForumPostDTO convertToDTO(ForumPost post, Long currentUserId) {
        ForumPostDTO dto = new ForumPostDTO();
        dto.setId(post.getId());
        dto.setAuthorId(post.getAuthor().getId());
        dto.setAuthorName(post.getAuthor().getNickname());
        dto.setAuthorAvatar(post.getAuthor().getAvatarUrl());
        dto.setContent(post.getContent());
        dto.setPostType(post.getPostType());
        dto.setLikeCount(post.getLikeCount());
        dto.setCommentCount(post.getCommentCount());
        dto.setViewCount(post.getViewCount());
        dto.setLatitude(post.getLatitude());
        dto.setLongitude(post.getLongitude());
        dto.setLocationName(post.getLocationName());
        dto.setBirdName(post.getBirdName());
        dto.setBirdSpecies(post.getBirdSpecies());
        dto.setLostLocation(post.getLostLocation());
        dto.setContactPhone(post.getContactPhone());
        dto.setReward(post.getReward());
        dto.setIsFound(post.getIsFound());
        dto.setCreatedAt(post.getCreatedAt());
        dto.setTimeAgo(formatTimeAgo(post.getCreatedAt()));
        
        // 图片
        List<PostImage> images = imageRepository.findByPostIdOrderBySortOrderAsc(post.getId());
        dto.setImages(images.stream().map(PostImage::getImageUrl).collect(Collectors.toList()));
        
        // 当前用户状态
        if (currentUserId != null) {
            dto.setIsLiked(likeRepository.existsByPostIdAndUserId(post.getId(), currentUserId));
            dto.setIsFavorited(favoriteRepository.existsByPostIdAndUserId(post.getId(), currentUserId));
            dto.setIsFollowing(followRepository.existsByFollowerIdAndFollowingId(currentUserId, post.getAuthor().getId()));
        }
        
        return dto;
    }
    
    /**
     * 转换评论为DTO
     */
    private PostCommentDTO convertCommentToDTO(PostComment comment, Long currentUserId) {
        PostCommentDTO dto = new PostCommentDTO();
        dto.setId(comment.getId());
        dto.setPostId(comment.getPost().getId());
        dto.setAuthorId(comment.getAuthor().getId());
        dto.setAuthorName(comment.getAuthor().getNickname());
        dto.setAuthorAvatar(comment.getAuthor().getAvatarUrl());
        dto.setContent(comment.getContent());
        dto.setLikeCount(comment.getLikeCount());
        dto.setParentId(comment.getParent() != null ? comment.getParent().getId() : null);
        dto.setCreatedAt(comment.getCreatedAt());
        dto.setTimeAgo(formatTimeAgo(comment.getCreatedAt()));
        
        if (currentUserId != null) {
            dto.setIsLiked(commentLikeRepository.existsByCommentIdAndUserId(comment.getId(), currentUserId));
        }
        
        return dto;
    }
    
    /**
     * 格式化相对时间
     */
    private String formatTimeAgo(LocalDateTime dateTime) {
        if (dateTime == null) return "";
        
        Duration duration = Duration.between(dateTime, LocalDateTime.now());
        long minutes = duration.toMinutes();
        long hours = duration.toHours();
        long days = duration.toDays();
        
        if (minutes < 1) return "刚刚";
        if (minutes < 60) return minutes + "分钟前";
        if (hours < 24) return hours + "小时前";
        if (days < 30) return days + "天前";
        if (days < 365) return (days / 30) + "个月前";
        return (days / 365) + "年前";
    }
}
